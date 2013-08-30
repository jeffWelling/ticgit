require 'ticgit-ng'
require 'ticgit-ng/command'

# used Cap as a model for this - thanks Jamis

module TicGitNG
  class CLI
    def self.execute
      parse(ARGV).execute!
    end

    def self.parse(args)
      #new() calls initialize(...) below
      cli = new(args)
      cli.parse_options!
      cli
    end

    attr_reader :action, :options, :args, :tic
    attr_accessor :out

    def initialize(args, path = '.', out = $stdout)
      @args = args.dup

      #set @init if one of the args is 'init'
      #this needs to be done because initialization of the ticgit branch must be done before
      #the branch is loaded, but because of the way commands are modularized this must be done
      #outside of and before the init.rb file itself is called (init.rb is where we would
      #normally put the code for such a command).
      args.include?( 'init' ) ? (@init=true) : (@init=false)
      #@init= ((args[0][/init/]=='init') rescue false)
      #@init= ((args[0][/init/]=='init') or (args[1][/init/]=='init') rescue false)
      
      @tic = TicGitNG.open(path, {:keep_state => true, :init => @init, :logger  => out })
      @options = OpenStruct.new
      @out = out

      @out.sync = true # so that Net::SSH prompts show up
    rescue NoRepoFound
      out.puts "No repo found"
      exit
    end

    def execute!
      if mod = Command.get(action)
        extend(mod)

        if respond_to?(:parser)
          option_parser = Command.parser(action, &method(:parser))
        else
          option_parser = Command.parser(action)
        end

        option_parser.parse!(args)

        execute if respond_to?(:execute)
      else
        puts usage

        if args.empty? and !action
          exit
        else
          puts('%p is not a command' % action)
          exit 1
        end
      end
    end

    def parse_options! #:nodoc:
      if args.empty?
        puts "Please specify at least one action to execute."
        puts
        puts usage(args)
        exit 1
      end

      #FIXME
      #this is a dirty hack that needs to be fixed
      if args.include?('list') and args.include?('init')
        @action = 'list'
      else
        @action = args.shift
      end
    end

    def usage(args = nil)
      old_args = args || [action, *self.args].compact

      if respond_to?(:parser)
        Command.parser('COMMAND', &method(:parser))
        # option_parser.parse!(args)
      else
        Command.usage(old_args.first, old_args)
      end
    end

    def get_editor_message(comments = nil)
      message_file = Tempfile.new('ticgitng_message').path
      File.open(message_file, 'w') { |f| f.puts comments } if comments

      editor = ENV["EDITOR"] || 'vim'
      system("#{editor} #{message_file}");
      message = File.readlines(message_file)
      message = message.select { |line| line[0, 1] != '#' } # removing comments
      if message.empty?
        return false
      else
        return message
      end
    end

    def ticket_show(t, more=nil)
        days_ago = ((Time.now - t.opened) / (60 * 60 * 24)).round

        data = [
            ['Title',    t.title],
            ['TicId',    t.ticket_id],
            '',
            ['Assigned', t.assigned],
            ['Opened',   "#{t.opened} (#{days_ago} days)"],
            ['State',    t.state.upcase],
            ['Points',   t.points || 'no estimate'],
            ['Tags',     t.tags.join(', ')],
            ''
        ]

        data.each do |(key, value)|
            puts(value ? "#{key}: #{value}" : key)
        end

        #FIXME display attachments inline chronologically with comments
        unless t.comments.empty? and t.attachments.empty?
            comments_and_attachments= Hash.new
            puts "Comments and attachments (#{t.comments.size + t.attachments.size}):"
            t.comments.each do |c|
                comments_and_attachments[c.added]=c
            end
            
            t.attachments.each do |a|
                comments_and_attachments[a.added]=a
            end
            comments_and_attachments.sort.each {|item|
                if item[1].class==TicGitNG::Comment
                    #print comment
                    puts "  * Added #{item[1].added.strftime('%m/%d %H:%M')} by #{item[1].user}"

                    wrapped = item[1].comment.split("\n").map{|line|
                        line.length > 80 ? line.gsub(/(.{1,80})(\s+|$)/, "\\1\n").strip : line
                    }.join("\n")

                    wrapped = wrapped.split("\n").map{|line| "\t#{line}" }

                    if wrapped.size > 6 and more.nil?
                        puts wrapped[0, 6].join("\n")
                        puts "\t** more... **"
                    else
                        puts wrapped.join("\n")
                    end
                    puts
                else
                    #print attachment
                    puts "  * Added #{item[1].added.strftime('%m/%d %H:%M')} by #{item[1].user}"
                    puts "    Attachment: #{t.attachments.index(item[1]) }"
                    puts "    Filename:   #{item[1].attachment_name}"
                    puts
                end
            }
        end
    end

    class << self
      attr_accessor :window_lines, :window_cols

      TIOCGWINSZ_INTEL = 0x5413     # For an Intel processor
      TIOCGWINSZ_PPC   = 0x40087468 # For a PowerPC processor
      STDOUT_HANDLE    = 0xFFFFFFF5 # For windows

      def reset_window_width
        try_using(TIOCGWINSZ_PPC) ||
        try_using(TIOCGWINSZ_INTEL) ||
          try_windows ||
          use_fallback
      end

      # Set terminal dimensions using ioctl syscall on *nix platform
      # TODO: find out what is raised here on windows.
      def try_using(mask)
        buf = [0,0,0,0].pack("S*")

        if $stdout.ioctl(mask, buf) >= 0
          self.window_lines, self.window_cols = buf.unpack("S2")
          true
        end
      rescue Errno::EINVAL, Errno::ENOTTY
      end

      def try_windows
        lines, cols = windows_terminal_size
        self.window_lines, self.window_cols = lines, cols if lines and cols
      end

      # Determine terminal dimensions on windows platform
      def windows_terminal_size
        m_GetStdHandle = Win32API.new(
          'kernel32', 'GetStdHandle', ['L'], 'L')
        m_GetConsoleScreenBufferInfo = Win32API.new(
          'kernel32', 'GetConsoleScreenBufferInfo', ['L', 'P'], 'L' )
        format = 'SSSSSssssSS'
        buf = ([0] * format.size).pack(format)
        stdout_handle = m_GetStdHandle.call(STDOUT_HANDLE)

        m_GetConsoleScreenBufferInfo.call(stdout_handle, buf)
        (bufx, bufy, curx, cury, wattr,
         left, top, right, bottom, maxx, maxy) = buf.unpack(format)
        return bottom - top + 1, right - left + 1
      rescue NameError
      end

      def use_fallback
        self.window_lines, self.window_cols = 25, 80
      end
    end

    def window_lines
      TicGitNG::CLI.window_lines
    end

    def window_cols
      TicGitNG::CLI.window_cols
    end

    if ''.respond_to?(:chars)
      # assume 1.9
      def just(value, size = 10, side = :left)
        value = value.to_s

        if value.bytesize > size
          sub_value = "#{value[0, size - 1]}+"
        else
          sub_value = value[0, size]
        end

        just_common(sub_value, size, side)
      end
    else
      def just(value, size = 10, side = :left)
        chars = value.to_s.scan(/./um)

        if chars.size > size
          sub_value = "#{chars[0, size-1]}+"
        else
          sub_value = chars.join
        end

        just_common(sub_value, size, side)
      end
    end

    def just_common(value, size, side)
      case side
      when :r, :right
        value.rjust(size)
      when :l, :left
        value.ljust(size)
      end
    end

    def puts(*strings)
      @out.puts(*strings)
    end
  end
end

TicGitNG::CLI.reset_window_width
begin
    Signal.trap("SIGWINCH") { TicGitNG::CLI.reset_window_width }
rescue
    TicGitNG::CLI.use_fallback
end
