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
        opts.on_head(
          "-s SOURCE", "--source SOURCE", "Source to sync with"){|v|
          options.source = v
        }
      end

      def execute
        if options.source
          #sync with third party bug tracker
          if options.repo and options.no_push
            tic.sync_tickets(options.repo, false)
          elsif options.repo
            tic.sync_tickets(options.repo)
          elsif options.no_push
            tic.sync_tickets('origin', false)
          else
            tic.sync_tickets()
          end
          
        else
          #sync with TicGit
          if options.repo and options.no_push
            tic.sync_tickets(options.repo, false)
          elsif options.repo
            tic.sync_tickets(options.repo)
          elsif options.no_push
            tic.sync_tickets('origin', false)
          else
            tic.sync_tickets()
          end
        end
      end
    end
  end
end
