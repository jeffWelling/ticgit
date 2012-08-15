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
          if options.repo
            puts "Notice: The -r / --repo argument is mutually exclusive with -s / --source, and is being ignored"
          end

          #sync with third party bug tracker
          if options.no_push
            TicGitNG::Sync.external_sync(options.source, false)
          else
            TicGitNG::Sync.external_sync(options.source)
          end
          
        else
          #sync with TicGit
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
