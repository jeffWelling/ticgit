require 'octokit'

module TicGitNG
  module Sync
    class Github_Issues < SyncableTicket
      def initialize(options={})
        return Github_Bugtracker.new(options)
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
    #Class used to interface with Octokit (Github Issues)
    class Github_Bugtracker 
      def initialize(options={})
        raise "Gitub_Bugtracker.new requires {:username=>'' and either :token or :password}" unless 
          options.has_key?(:username) and (options.has_key?( :token ) || options.has_key?( :password ) )

        if options.has_key? :token
          @client=Octokit::Client.new( {:login=>options[:username], :token=>options[:token]} )
        else
          @client=Octokit::Client.new( {:login=>options[:username], :password=>options[:password]} )
        end
      end

    end
  end
end
