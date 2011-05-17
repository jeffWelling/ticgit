module TicGitNG
  module Command
    module Title
      def parser(opts)
        opts.banner="Usage: ti title [ticid] \"new_title\""
      end
      def execute
        #if a ticid is provided...
        if args.size > 1
          tid, new_title = args[0].strip, args[1].strip

          tic.ticket_title(new_title, tid)
        #otherwise, args only contains new_title
        elsif
          new_title=args[0].strip
          tic.ticket_title(new_title)

        else

          puts "You forgot to provide the new title!"
          puts "Usage: ti title \"My new ticket title\""
        end
      end
    end
  end
end
