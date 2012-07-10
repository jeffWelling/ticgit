module TicGitNG
  module Command
    # Shows help for ticgit or a particular command
    #
    # Usage:
    # ti help               (show help for ticgit)
    # ti help {command}     (show help for specified command)
    module Help
      def parser(opts)
        opts.banner = "Usage: ti help [command]\n"
      end
      def execute
        cli = CLI.new([])
        if ARGV.length >= 2 # ti help {command}
          action = ARGV[1]
          if command = Command.get(action)
            cli.extend(command)
          else
            puts "Unknown command #{action}\n\n"
          end
        end
        puts cli.usage
      end
    end
  end
end

