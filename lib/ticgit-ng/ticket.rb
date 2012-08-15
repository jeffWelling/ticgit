module TicGitNG
  class Ticket

    attr_reader :base, :opts
    attr_accessor :ticket_id, :ticket_name
    attr_accessor :title, :state, :milestone, :assigned, :opened, :points
    attr_accessor :comments, :tags, :attachments # arrays

    def initialize(base, options = {})
      # FIXME: what/where/who/how changed config to hash?
      if (cfg = base.git.config).is_a? Hash
        options[:user_name] ||= cfg["user.name"]
        options[:user_email] ||= cfg["user.email"]
      else
        options[:user_name] ||= cfg("user.name")
        options[:user_email] ||= cfg("user.email")
      end

      @base = base
      @opts = options || {}

      @state = 'open' # by default
      @comments = []
      @tags = []
      @attachments = []
    end

    def self.create(base, title, options = {}, time=nil)
      t = Ticket.new(base, options)
      t.title = title
      t.ticket_name = self.create_ticket_name(title, time)
      t.save_new
      t
    end

    def self.open(base, ticket_name, ticket_hash, options = {})
      tid = nil

      t = Ticket.new(base, options)
      t.ticket_name = ticket_name

      title, date = self.parse_ticket_name(ticket_name)
      t.opened = date

      ticket_hash['files'].each do |fname, sha|
        if fname == 'TICKET_ID'
          tid = sha
        elsif fname == 'TICKET_TITLE'
          t.title = base.git.gblob(sha).contents
        else
          # matching
          data = fname.split('_')

          case data[0]
          when 'ASSIGNED'
            t.assigned = data[1..-1].join('_')
          when 'ATTACHMENTS'
              #Attachments dir naming format:
              #ticket_name/ATTACHMENTS/123456_jeff.welling@gmail.com_fubar.jpg
              #data[] format:
              #"ATTACHMENTS_1342116799_jeff.welling@gmail.com_Rakefile".split('_')
            filename=File.join( 'ATTACHMENTS', fname.gsub(/^ATTACHMENTS_/,'') )
            t.attachments << TicGitNG::Attachment.new( filename )
          when 'COMMENT'
            t.comments << TicGitNG::Comment.read(base, fname, sha)
          when 'POINTS'
            t.points = base.git.gblob(sha).contents.to_i
          when 'STATE'
            t.state = data[1]
          when 'TAG'
            t.tags << data[1]
          when 'TITLE'
            t.title = base.git.gblob(sha).contents
          end
        end
      end

      if !t.attachments.class==NilClass and t.attachments.size > 1
          t.attachments= t.attachments.sort {|a1, a2| a1.added <=> a2.added }
      end
      t.ticket_id = tid
      t
    end

    def self.parse_ticket_name(name)
      epoch, title, rand = name.split('_')
      title = title.gsub('-', ' ')
      return [title, Time.at(epoch.to_i)]
    end

    # write this ticket to the git database
    def save_new
      base.in_branch do |wd|
        files=[]
        t=nil
        base.logger.puts "saving #{ticket_name}"

        Dir.mkdir(ticket_name)
        Dir.chdir(ticket_name) do
          #ticket_name is in the format of
          # "#{Time.now.to_i}_#{cleaned(ticket_name)_#{rand(999)}"
          # So, the ticket ID is based on the time the ticket was created,
          #the title of the ticket when it was created, and a random number,
          #presumably for uniqueness.
          base.new_file('TICKET_ID', ticket_name)
          files << File.join( ticket_name, 'TICKET_ID' )
          base.new_file('TICKET_TITLE', title)
          files << File.join( ticket_name, 'TICKET_TITLE' )
          base.new_file( (t='ASSIGNED_'+email) , email)
          files << File.join( ticket_name, t )
          base.new_file( (t='STATE_'+state) , state)
          files << File.join( ticket_name, t )
          base.new_file('TITLE', title)
          files << File.join( ticket_name, 'TITLE' )

          # add initial comment
          #COMMENT_080315060503045__schacon_at_gmail
          if opts[:comment]
            base.new_file(t=comment_name(email), opts[:comment])
            files << File.join( ticket_name, t )
          end

          # add initial tags
          if opts[:tags] && opts[:tags].size > 0
            opts[:tags] = opts[:tags].map { |t| t.strip }.compact
            opts[:tags].each do |tag|
              if tag.size > 0
                tag_filename = 'TAG_' + Ticket.clean_string(tag)
                if !File.exists?(tag_filename)
                  base.new_file(tag_filename, tag_filename)
                  files << File.join( ticket_name, tag_filename )
                end
              end
            end
          end
        end
        files.each {|file|
          base.git.add file
        }
        base.git.commit("added ticket #{ticket_name}")
      end
      # ticket_id
    end

    def self.clean_string(string)
      string.downcase.gsub(/[^a-z0-9]+/i, '-')
    end

    def add_comment(comment)
      return false if !comment
      base.in_branch do |wd|
        t=nil
        Dir.chdir(ticket_name) do
          base.new_file(t=comment_name(email), comment)
        end
        base.git.add File.join(ticket_name, t)
        base.git.commit("added comment to ticket #{ticket_name}")
      end
      @comments << TicGitNG::Comment.new( comment, email, filename )
      self
    end

    def add_attach( base, filename, time=nil )
        filename=File.expand_path(filename)
        #FIXME Refactor -- Attachment.new should be called from Ticket.rb
        #               -- Attachment filename creation should be handled
        #                  by the Attachment.rb code
        base.in_branch do |wd|
            attachments << (a=TicGitNG::Attachment.create( filename, self, time))
            base.git.add File.join( ticket_name, a.filename )
            base.git.commit("added attachment #{File.basename(a.filename)} to ticket #{ticket_name}")
        end
        if attachments.class!=NilClass and attachments.size > 1
            @attachments=attachments.sort {|a1,a2| a1.added <=> a2.added }
        end
        self
    end

    #file_id can be one of:
    #  - An index number of the attachment (1,2,3,...)
    #  - A filename (fubar.jpg)
    #  - nil (nil) means use the last attachment
    #
    #if new_filename is nil, use existing filename
    def get_attach file_id=nil, new_filename=nil
        attachment=nil
        pwd=Dir.pwd
        base.in_branch do |wd|
            if file_id.to_i==0 and (file_id=="0" or file_id.class==Fixnum)
                if !attachments[file_id.to_i].nil?
                    attachment= attachments[0]
                else
                    puts "No attachments match file id #{file_id}"
                    exit 1
                end
            elsif file_id.to_i  > 0
                if !attachments[file_id.to_i].nil?
                    attachment= attachments[file_id.to_i]
                else
                    puts "No attachments match file id #{file_id}"
                    exit 1
                end
            else
                #find attachment by filename
                attachments.each {|a|
                    attachment=a if a.attachment_name==file_id
                }
                if attachment.nil?
                  puts "No attachments match filename #{file_id}"
                  exit 1
                end
            end

            if !new_filename
                #if no filename is specified...
                filename= attachment.attachment_name
            else
                #if there is a new_filename given
                if File.exist?( new_filename ) and File.directory?( new_filename )
                    #if it is a directory, not a filename
                    filename= File.join(
                        new_filename,
                        File.basename(attachment.attachment_name)
                    )
                else
                    #if it is a filename, not a dir
                    filename= new_filename
                end
            end

            unless File.exist?( File.dirname(filename) )
                FileUtils.mkdir_p( File.dirname(filename) )
            end
            #save attachment [as new_filename]
            t=File.join( ticket_name, attachment.filename )
            unless filename[/^\//]
                filename=File.join( pwd, filename )
            end
            FileUtils.cp( t, filename )
        end
        self
    end

    def change_state(new_state)
      return false if !new_state
      return false if new_state == state
      t=nil

      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          base.new_file(t='STATE_' + new_state, new_state)
        end
        base.git.remove(File.join(ticket_name,'STATE_' + state))
        base.git.add File.join(ticket_name, t)
        base.git.commit("added state (#{new_state}) to ticket #{ticket_name}")
      end
      @state=new_state
      self
    end

    def change_assigned(new_assigned)
      new_assigned ||= email
      old_assigned= assigned || ''
      return false if new_assigned == old_assigned

      base.in_branch do |wd|
        t=nil
        Dir.chdir(ticket_name) do
          base.new_file(t='ASSIGNED_' + new_assigned, new_assigned)
        end
        base.git.remove(File.join(ticket_name,'ASSIGNED_' + old_assigned))
        base.git.add File.join(ticket_name,t)
        base.git.commit("assigned #{new_assigned} to ticket #{ticket_name}")
      end
      @assigned=new_assigned
      self
    end

    def change_comment(replacement_msg, comment_filename, override)
      #append if not appended
      #this allows syncing to provide the tag before passing the replacemnet message, meaning we can
      #tag with the *actual* updated at time instead of the time the comment was updated via our sync
      unless was_updated?(replacement_msg)
        replacement_msg + "\n#Updated_at=#{Time.now.to_s}"
      end
      if override.class==TrueClass
        #change comment the comment even though we didn't author it
        #this could cause problems with bug trackers which don't let
        #us update comments we didn't author
        base.in_branch do |wd|
          base.git.remove(File.join(ticket_name, comment_filename)) rescue nil
          Dir.chdir(ticket_name) do
            base.new_file( comment_filename, replacement_msg)
          end
          base.git.add
          base.git.commit("changed comment #{comment_filename}")
        end
      else
        #only change comment if we wrote it
        if comment_filename.split('_')[2].downcase == opts[:user_email].downcase.strip
          base.in_branch do |wd|
            base.git.remove(File.join(ticket_name, comment_filename)) rescue nil
            Dir.chdir(ticket_name) do
              base.new_file( comment_filename, replacement_msg)
            end
            base.git.add
            base.git.commit("changed comment #{comment_filename}")
          end
        end
      end
    end

    def change_title(new_title)
      return false unless new_title.class==String
      return false if new_title==title

      base.in_branch do |wd|
        base.git.remove(File.join(ticket_name, 'TITLE') ) rescue nil  #the rescue nil helps smooth over any errors caused by the file not existing, likely due to running into a bug in the next line or two
        Dir.chdir(ticket_name) do
          base.new_file( 'TITLE', new_title)
        end
        base.git.add
        base.git.commit("changed title to \"#{new_title}\" on ticket #{ticket_name}")
      end
    end


    def change_points(new_points)
      return false if new_points == points

      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          base.new_file('POINTS', new_points)
        end
        base.git.add File.join(ticket_name, 'POINTS')
        base.git.commit("set points to #{new_points} for ticket #{ticket_name}")
      end
      @points=new_points
      self
    end

    def add_tag(tag)
      return false if !tag
      files=[]
      added = false
      tags = tag.split(',').map { |t| t.strip }
      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          tags.each do |add_tag|
            if add_tag.size > 0
              tag_filename = 'TAG_' + Ticket.clean_string(add_tag)
              if !File.exists?(tag_filename)
                base.new_file(tag_filename, tag_filename)
                files << File.join( ticket_name, tag_filename )
                added = true
              end
            end
          end
        end
        if added
          files.each {|file|
            base.git.add file
          }
          base.git.commit("added tags (#{tag}) to ticket #{ticket_name}")
        end
      end
      tags.each {|tag|
        @tags << tag
      }
      self
    end

    def remove_tag(tag)
      return false if !tag
      removed = false
      tags = tag.split(',').map { |t| t.strip }
      base.in_branch do |wd|
        tags.each do |add_tag|
          tag_filename = File.join(ticket_name, 'TAG_' + Ticket.clean_string(add_tag))
          if File.exists?(tag_filename)
            base.git.remove(tag_filename)
            removed = true
          end
        end
        if removed
          base.git.commit("removed tags (#{tag}) from ticket #{ticket_name}")
        end
      end
      @tags.delete_if {|t| t==tag }
      self
    end

    def path
      File.join(state, ticket_name)
    end

    def comment_name(email)
      'COMMENT_' + Time.now.to_i.to_s + '_' + email
    end

    def email
      opts[:user_email] || 'anon'
    end

    def updated_at
      base.in_branch do |wd|
        base.git.log.object(ticket_name).first.date
      end
    end

    def assigned_name
      assigned.split('@').first rescue ''
    end

    def self.create_ticket_name(title, time=nil)
      [time.nil? ? Time.now.to_i.to_s : time, Ticket.clean_string(title), rand(999).to_i.to_s].join('_')
    end

    #return true if comment_msg contains \n#Updated_at=#{Time.now.to_s}  tag
    def was_updated? comment_msg
      tag=comment_msg.split("\n").reverse[0][/\#Updated_at=[^=](.{1,8}\s){4}\d{4}$/] rescue (return false)
      #DateTime can parse Time.now.to_s strings, so if tag is parsable then the tag is valid
      DateTime.parse tag.gsub("#Updated_at=",'') rescue (return false)
      true
    end

    def create_attachment_name( attachment_name, time=nil )
        raise ArgumentError, "create_attachment_name( ) only takes a string" unless attachment_name.class==String
        if time
            if time.to_i == 0
                raise ArgumentError, "argument 'time' is not valid"  unless time.class==Fixnum
            else
                time=time.to_i
            end
        end
        time or time=Time.now.to_i
        time.to_s+'_'+email+'_'+File.basename( attachment_name )
    end

    def ==(ticket2)
        self.instance_variables.each {|instance_var|
            unless send( instance_var.gsub('@','').to_sym ) == ticket2.instance_eval {send(instance_var.gsub('@','').to_sym)}
                return false
            end
        }
        return true
    end
  end
end
