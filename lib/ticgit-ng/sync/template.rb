module TicGitNG
  module Sync
    class Template < SyncableTicket
      def initialize(options={})
        @static_fields=%w()
      end
      attr_reader :static_fields

      #create new ticket
      def create
      end

      #read tickets
      #if ticket number is not nil, return associated ticket
      #else return all tickets.
      def read( ticket_number=nil )
      end

      #alter an existing ticket
      def update
      end

      #delete existing ticket
      #this should not need to be called very often, if at all
      def destroy
      end
    end
  end
end
