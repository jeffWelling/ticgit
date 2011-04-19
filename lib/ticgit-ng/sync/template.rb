module TicGitNG
  module Sync
    class Github_Issues
      def initialize(options={})
        @client= Github_Bugtracker.new(options)
      end
      #list all tickets
      #called from lib/ticgit-ng/sync.rb, used to get all tickets
      def index
      end

      #get all info for one ticket
      #
      def show
      end

      #create new ticket
      def create
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