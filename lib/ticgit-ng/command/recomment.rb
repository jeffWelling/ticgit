module TicGitNG
  module Command
    module Recomment
      def parser(opts)
        opts.banner="Usage: ti recomment [options]"
        opts.on_head(
          "-m MESSAGE", "--message MESSAGE", "Replace the existing comment with MESSAGE"){|v|
          options.message=v
        }
        #TODO add -f --file argument to provide message from a file
        opts.on_head(
          "-t TICKET", "--ticket TICKET", "Checkout this ticket"){|v|
          options.ticket=v
        }
        opts.on_head(
          "-c COMMENT_ID", "--comment COMMENT_ID", "Edit the comment identified by COMMENT_ID"){|v|
          raise ArgumentError, "The -c/--comment switch cannot be used without -t/--ticket" unless options.ticket
          options.comment= v
        }
        opts.on_head( 
          "-o", "--override", "Allow editing a comment you didn't create") do
          options.override= true
        end
        #
      end

      def execute
        return unless message= (options.messsage || get_editor_message)
        tic.ticket_checkout(options.ticket) if options.ticket

        tic.ticket_recomment( message, options.ticket, options.comment, options.override )
      end
    end
  end
end
