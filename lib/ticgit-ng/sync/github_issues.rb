require 'octokit'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      def initialize(options={})
        @client=Github_Issues_Bugtracker.new(options).client
      end

      def create
      end
      
      def read
      end
      
      def update
      end
      
      def destroy
      end

    end
    #Class used to interface with Octokit (Github Issues)
    class Github_Issues_Bugtracker 
      def initialize(options={})
        raise "Gitub_Bugtracker.new requires {:username=>'' and either :token or :password}" unless 
          options.has_key?(:username) and (options.has_key?( :token ) || options.has_key?( :password ) )

        if options.has_key? :token
          @client=Octokit::Client.new( {:login=>options[:username], :token=>options[:token]} )
        else
          @client=Octokit::Client.new( {:login=>options[:username], :password=>options[:password]} )
        end
      end
      attr_reader :client
    end
  end
end
