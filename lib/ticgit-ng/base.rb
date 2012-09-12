module TicGitNG
  class NoRepoFound < StandardError;end
  class Base

    attr_reader :git, :logger
    attr_reader :tic_working, :tic_index, :tic_dir
    attr_reader :last_tickets, :current_ticket  # saved in state
    attr_reader :config
    attr_reader :state, :config_file

    def initialize(git_dir, opts = {})
      @git = Git.open(find_repo(git_dir))

      begin
        git.lib.full_log_commits :count => 1
      rescue
        puts "Git error: please check your git repository, you must have at least one commit in git"
        exit 1
      end

      @logger = opts[:logger] || Logger.new(STDOUT)

      #This is to accomodate for edge-cases where @logger.puts
      #is called from debugging code.
      if @logger.respond_to?(:puts) && !@logger.respond_to?(:info)
        @logger.class.class_eval do
          alias :info :puts
        end
      elsif @logger.respond_to?(:info) && !@logger.respond_to?(:puts)
        @logger.class.class_eval do
          alias :puts :info
        end
      end
         
      @last_tickets = []
      @init=opts[:init]

      proj = Ticket.clean_string(@git.dir.path)

      #Use this hack instead of git itself because this is ridiculously faster then
      #getting the same information from git
      branches= Dir.entries( File.join(find_repo(git_dir),'.git/refs/heads/') ).delete_if {|i|
        i=='.' || i=='..'
      }
      branch= branches.include?('ticgit-ng') ? ('ticgit-ng') : ('ticgit')

      @tic_dir = opts[:tic_dir] ||"~/.#{branch}"
      @tic_working = opts[:working_directory] || File.expand_path(File.join(@tic_dir, proj, 'working'))
      @tic_index = opts[:index_file] || File.expand_path(File.join(@tic_dir, proj, 'index'))

      @last_tickets = []

      #expire @tic_index and @tic_working if it mtime is older than 
      #git log.  Otherwise, during testing, if you use the same temp
      #directory with the same name, deleting it and recreating it
      #to test something, ticgit would get confused by the cache from
      #the previous instance of the temp dir.
      if File.exist?(@tic_working)
        cache_mtime=File.mtime(@tic_working)
        begin
          gitlog_mtime= File.mtime(File.join( find_repo('.'), ".git/refs/heads/#{branch}" ))
        rescue
          reset_cache
        end

        #unless (cache_mtime > gitlog_mtime.-(20) and cache_mtime <= gitlog_mtime) or (cache_mtime > gitlog_mtime.+(30) and cache_mtime >= gitlog_mtime)
        #FIXME break logic out into several lines
        #FIXME don't bother resetting if gitlog_mtime.to_i == 0
        if needs_reset?( cache_mtime, gitlog_mtime ) and !cache_mtime==gitlog_mtime
          puts "Resetting cache" unless gitlog_mtime.to_i == 0
          reset_cache
        end

      end

      # load config file
      @config_file = File.expand_path(File.join(@tic_dir, proj, 'config.yml'))
      if File.exists?(config_file)
        @config = YAML.load(File.read(config_file))
      else
        @config = {}
      end

      @state = File.expand_path(File.join(@tic_dir, proj, 'state'))

      unless branches.include?(branch) && File.directory?(@tic_working)
        if branches.include?(branch) and !File.exist?(@tic_working)
          #branch exists but tic_working doesn't
          #this could be because the dir was deleted or the repo itself
          #was moved, so recreate the dir.
          reset_ticgitng
        elsif @init
          puts "Initializing TicGit-ng"
          init_ticgitng_branch( branches.include?(branch) )
        else
          puts "Please run `ti init` to initialize TicGit-ng for this repository before running other ti commands."
          exit
        end
      end

      if File.file?(@state)
        load_state
      else
        reset_ticgitng
      end
    end

    def find_repo(dir)
      full = File.expand_path(dir)
      ENV["GIT_WORKING_DIR"] || loop do
        return full if File.directory?(File.join(full, ".git"))
        raise NoRepoFound if full == full=File.dirname(full)
      end
    end

    # marshal dump the internals
    # save config file
    def save_state
      state_list = [@last_tickets, @current_ticket]
      unless File.exist? @state
        FileUtils.mkdir_p( File.dirname(@state) )
      end
      File.open(@state, 'w+'){|io| Marshal.dump(state_list, io) }
      File.open(@config_file, 'w+'){|io| io.write(config.to_yaml) }
    end

    # read in the internals
    def load_state
      state_list = File.open(@state){|io| Marshal.load(io) }
      garbage_data=nil
      if state_list.length == 2
        @last_tickets, @current_ticket = state_list
      else
        #This was left behind so that people can continue load_state-ing
        #without having to delete their ~/.ticgit directory when
        #updating to this version (rename to ticgit-ng)
        garbage_data, @last_tickets, @current_ticket = state_list
      end
    end

    # returns new Ticket
    def ticket_new(title, options = {}, time=nil)
      t = TicGitNG::Ticket.create(self, title, options, time)
      reset_ticgitng
      TicGitNG::Ticket.open(self, t.ticket_name, tickets[t.ticket_name])
    end

    #This is a legacy function from back when ticgit-ng needed to have its
    #cache reset in order to avoid cache corruption.
    def reset_ticgitng
      tickets
      save_state
    end

    # returns new Ticket
    def ticket_comment(comment, ticket_id = nil)
      if t = ticket_revparse(ticket_id)
        ticket = TicGitNG::Ticket.open(self, t, tickets[t])
        ticket.add_comment(comment)
        reset_ticgitng
        ticket
      end
    end

    # returns array of Tickets
    def ticket_list(options = {})
      reset_ticgitng
      ts = []
      @last_tickets = []
      @config['list_options'] ||= {}

      tickets.to_a.each do |name, t|
        ts << TicGitNG::Ticket.open(self, name, t)
      end

      if name = options[:saved]
         if c = config['list_options'][name]
           options = c.merge(options)
         end
      end

      if options[:list]
        # TODO : this is a hack and i need to fix it
        config['list_options'].each do |name, opts|
          puts name + "\t" + opts.inspect
        end
        return false
      end

      if options.size == 0
        # default list
        options[:state] = 'open'
      end

      # :tag, :state, :assigned
      if t = options[:tags]
        t = {false => Set.new, true => Set.new}.merge t.classify { |x| x[0,1] != "-" }
        t[false].map! { |x| x[1..-1] }
        ts = ts.reject { |tic| t[true].intersection(tic.tags).empty? } unless t[true].empty?
        ts = ts.select { |tic| t[false].intersection(tic.tags).empty? } unless t[false].empty?
      end
      if s = options[:states]
        s = {false => Set.new, true => Set.new}.merge s.classify { |x| x[0,1] != "-" }
        s[true].map! { |x| Regexp.new(x, Regexp::IGNORECASE) }
        s[false].map! { |x| Regexp.new(x[1..-1], Regexp::IGNORECASE) }
        ts = ts.select { |tic| s[true].any? { |st| tic.state =~ st } } unless s[true].empty?
        ts = ts.reject { |tic| s[false].any? { |st| tic.state =~ st } } unless s[false].empty?
      end
      if a = options[:assigned]
        ts = ts.select { |tic| tic.assigned =~ Regexp.new(a, Regexp::IGNORECASE) }
      end

      # SORTING
      if field = options[:order]
        field, type = field.split('.')

        case field
        when 'assigned'; ts = ts.sort_by{|a| a.assigned }
        when 'state';    ts = ts.sort_by{|a| a.state }
        when 'date';     ts = ts.sort_by{|a| a.opened }
        when 'title';    ts = ts.sort_by{|a| a.title }
        end

        ts = ts.reverse if type == 'desc'
      else
        # default list
        ts = ts.sort_by{|a| a.opened }
      end

      if options.size == 0
        # default list
        options[:state] = 'open'
      end

      # :tag, :state, :assigned
      if t = options[:tag]
        ts = ts.select { |tag| tag.tags.include?(t) }
      end
      if s = options[:state]
        ts = ts.select { |tag| tag.state =~ /#{s}/ }
      end
      if a = options[:assigned]
        ts = ts.select { |tag| tag.assigned =~ /#{a}/ }
      end

      if save = options[:save]
        options.delete(:save)
        @config['list_options'][save] = options
      end

      @last_tickets = ts.map{|t| t.ticket_name }
      # :save

      save_state
      ts
    end

    # returns single Ticket
    def ticket_show(ticket_id = nil)
      # ticket_id can be index of last_tickets, partial sha or nil => last ticket
      reset_ticgitng
      if t = ticket_revparse(ticket_id)
        return TicGitNG::Ticket.open(self, t, tickets[t])
      end
    end

    # returns recent ticgit-ng activity
    # uses the git logs for this
    def ticket_recent(ticket_id = nil)
      if ticket_id
        t = ticket_revparse(ticket_id)
        return git.log.object(which_branch?).path(t)
      else
        return git.log.object(which_branch?)
      end
    end

    def ticket_revparse(ticket_id)
      if ticket_id
        ticket_id = ticket_id.strip

        if /^[0-9]*$/ =~ ticket_id && (t = @last_tickets[ticket_id.to_i - 1])
          return t
        elsif ticket_id.length > 4 # partial (5 characters or greater to be considered unique enough) or full sha
          regex = /^#{Regexp.escape(ticket_id)}/
          ch = tickets.select{|name, t|
            t['files'].assoc('TICKET_ID')[1] =~ regex }
          ch.first[0] if ch.first
        end
      elsif(@current_ticket)
        return @current_ticket
      end
    end

    def ticket_tag(tag, ticket_id = nil, options = OpenStruct.new)
      if t = ticket_revparse(ticket_id)
        ticket = TicGitNG::Ticket.open(self, t, tickets[t])
        if options.remove
          ticket.remove_tag(tag)
        else
          ticket.add_tag(tag)
        end
        reset_ticgitng
        ticket
      end
    end

    def ticket_change(new_state, ticket_id = nil)
      if t = ticket_revparse(ticket_id)
        if tic_states.include?(new_state)
          ticket = TicGitNG::Ticket.open(self, t, tickets[t])
          ticket.change_state(new_state)
          reset_ticgitng
          ticket
        end
      end
    end

    def ticket_assign(new_assigned = nil, ticket_id = nil)
      if t = ticket_revparse(ticket_id)
        ticket = TicGitNG::Ticket.open(self, t, tickets[t])
        ticket.change_assigned(new_assigned)
        reset_ticgitng
        ticket
      end
    end

    def ticket_points(new_points = nil, ticket_id = nil)
      if t = ticket_revparse(ticket_id)
        ticket = TicGitNG::Ticket.open(self, t, tickets[t])
        ticket.change_points(new_points)
        reset_ticgitng
        ticket
      end
    end

    def ticket_checkout(ticket_id)
      if t = ticket_revparse(ticket_id)
        ticket = TicGitNG::Ticket.open(self, t, tickets[t])
        @current_ticket = ticket.ticket_name
        save_state
        ticket
      end
    end

    def tic_states
      ['open', 'resolved', 'invalid', 'hold']
    end

    def sync_tickets(repo='origin', push=true, verbose=true )
      puts "Fetching #{repo}" if verbose
      @git.fetch(repo)
      puts "Syncing tickets with #{repo}" if verbose
      remote_branches=@git.branches.remote.map{|b|
        b.full.gsub('remotes/', '')[Regexp.new("^#{Regexp.escape(repo)}/.*")]
      }.compact
      remote_branches.include?("#{repo}/ticgit-ng") ? r_ticgit='ticgit-ng' : r_ticgit='ticgit'
      in_branch(false) do
        repo_g=git.remote(repo)
        git.pull(repo_g, repo+'/'+r_ticgit)
        git.push(repo_g, "#{which_branch?}:"+r_ticgit ) if push
        puts "Tickets synchronized." if verbose
      end
    end

    def tickets
      read_tickets
    end

    def read_tickets
      tickets = {}

      tree = git.lib.full_tree(which_branch?)
      tree.each do |t|
        data, file = t.split("\t")
        mode, type, sha = data.split(" ")
        tic = file.split('/')
        if tic.size == 2  # directory depth
            ticket, info = tic
            tickets[ticket] ||= { 'files' => [] }
            tickets[ticket]['files'] << [info, sha]
        elsif tic.size == 3
            ticket, attch_dir, filename = tic
            if filename
                filename = 'ATTACHMENTS_' + filename
                tickets[ticket] ||= { 'files' => [] }
                tickets[ticket]['files'] << [filename, sha]
            end
        end
      end
      tickets
    end

    def init_ticgitng_branch(ticgitng_branch = false)
      @logger << 'creating ticgit-ng repo branch'

      in_branch(ticgitng_branch) do
        #The .hold file seems to have little to no purpose aside from helping
        #figure out if the branch should be checked out or not.  It is created
        #when the ticgit branch is created, and seems to exist for the lifetime
        #of the ticgit branch. The purpose seems to be, to be able to tell if
        #the ticgit branch is already checked out and not check it out again if
        #it is.  This might be superfluous after switching to grit.
        new_file('.hold', 'hold')

        unless ticgitng_branch
          git.add ".hold"
          git.commit('creating the ticgit-ng branch')
        end
      end
    end

    # temporarlily switches to ticgit branch for tic work
    def in_branch(branch_exists = true)
      needs_checkout = false

      unless File.directory?(@tic_working)
        FileUtils.mkdir_p(@tic_working)
        needs_checkout = true
      end
      needs_checkout = true unless File.file?('.hold')

      old_current = git.lib.branch_current
      begin
        git.lib.change_head_branch(which_branch?)
        git.with_index(@tic_index) do
          git.with_working(@tic_working) do |wd|
            git.lib.checkout(which_branch?) if needs_checkout &&
              branch_exists
            yield wd
          end
        end
      ensure
        git.lib.change_head_branch(old_current)
      end
    end

    def new_file(name, contents)
      File.open(name, 'w+'){|f| f.puts(contents) }
    end

    def which_branch?
      #At present use the 'ticgit' branch for backwards compatibility
      branches=@git.branches.local.map {|b| b.name}
      if branches.include? 'ticgit-ng'
        return 'ticgit-ng'
      else
        return 'ticgit'
      end

      #If has ~/.ticgit dir, and 'ticgit' branch
      #If has ~/.ticgit-ng dir, and 'ticgit-ng' branch, and not ~/.ticgit dir and not 'ticgit' branch
    end

    def reset_cache
      #@state, @tic_index, @tic_working
      #A rescue is appended to the end of each line because it allows
      #execution of others to continue upon failure, as opposed to
      #a begin;rescue;end segment.
      FileUtils.rm_r File.expand_path(@tic_working) rescue nil
      FileUtils.rm File.expand_path(@state) rescue nil
      FileUtils.rm File.expand_path(@tic_index) rescue nil
      FileUtils.mkdir_p File.expand_path(@tic_working) rescue nil
      @state=nil
    end

    def needs_reset? cache_mtime, gitlog_mtime
      ((cache_mtime.to_i - gitlog_mtime.to_i) > 120) or ((gitlog_mtime.to_i - cache_mtime.to_i) > 120)
    end
    
    def ticket_attach filename, ticket_id=nil, time=nil
        t = ticket_revparse( ticket_id )
        ticket= TicGitNG::Ticket.open( self, t, tickets[t] )
        ticket.add_attach( self, filename, time )
        reset_ticgitng
        ticket
    end

    #ticket_get_attachment()
    #file_id -      return the attachment identified by file_id
    #new_filename - save the attachment as new_filename
    #ticket_id -    get the attachment from ticket_id instead of current
    def ticket_get_attachment file_id=nil, new_filename=nil, ticket_id=nil 
        if t = ticket_revparse(ticket_id)
            ticket = Ticket.open( self, t, tickets[t] )
            ticket.get_attach( file_id, new_filename )
        end
    end
  end
end
