module TicGitNG
  module Command
    module Sync
      def parser(opts)
        opts.banner = "Usage: ti sync [options]"
        opts.on_head(
          "-r REPO", "--repo REPO", "Sync ticgit-ng branch with REPO"){|v|
          options.repo = v
        }
        opts.on_head(
          "-n", "--no-push", "Do not push to the remote repo"){|v|
          options.no_push = true
        }
      end

      def execute
        begin
          if options.repo and options.no_push
            tic.sync_tickets(options.repo, false)
          elsif options.repo
            tic.sync_tickets(options.repo)
          elsif options.no_push
            tic.sync_tickets('origin', false)
          else
            tic.sync_tickets()
          end
        rescue Git::GitExecuteError => e
          if e.message[/does not appear to be a git repository/]
            repo= e.message.split("\n")[0][/^[^:]+/][/"\w+"/].gsub('"','')
            puts "Could not sync because git returned the following error:\n#{e.message.split("\n")[0][/[^:]+$/].strip}"
            exit
          end
        end 
      end
    end
  end
end
