module TicGitNG
  module Command
    module Tag
      def parser(opts)
        opts.banner = "Usage: ti tag [tic_id] [options] [tag_name] "
        opts.on_head(
          "-d", "--delete",
          "Remove this tag from the ticket"){|v| options.remove = v }
      end

      def execute
        if options.remove
          puts 'remove'
        end

        if ARGV.size > 2 # `ti tag 1234abc tagname1`
          tic.ticket_tag(ARGV[2], ARGV[1].chomp, options)
        elsif ARGV.size == 2 # `ti tag tagname1`
          tic.ticket_tag(ARGV[1], nil, options)
        else
          puts 'You need to at least specify one tag to add'
          puts
          puts usage
        end
      end
    end
  end
end
