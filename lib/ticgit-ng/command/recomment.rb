module TicGitNG
  module Command
    module Recomment
      def parser(opts)
        opts.banner="Usage: ti recomment [options]"
        opts.on_head(
          "-m MESSAGE", "--message MESSAGE", "Replace the existing comment with MESSAGE"){|v|
          options.message=v
        }
        opts.on_head(
          "-t TICKET", "--ticket TICKET", "Checkout this ticket"){|v|
          options.checkout=v
        }
        opts.on_head(
          "-c COMMENT", "--comment COMMENT", "Edit COMMENT instead of latest comment"){|v|
          options.comment= v
        }
        opts.on_head( 
          "-o", "--override", "Edit a comment you didn't create") do
          options.override= true
        end
        #
      end

      def execute

      end
    end
  end
end
