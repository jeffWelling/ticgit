require 'octokit'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      def initialize(options={})
        @client=Github_Issues_Bugtracker.new(options).client
        @static_attributes=%w(created_at gravatar_id html_url)
      end
      attr_reader :static_attributes

      def create
      end
      
      #read all issues in repo if issue_num.nil?
      #read issue_num in repo if issue_num.class==Fixnum
      def read( repo, issue_num=nil )
        raise "read(repo,issue_num): issue must be nil or integer" unless
          issue_num.nil? or issue_num.class==Fixnum
       
        if issue_num.nil? 
          issues=@client.issues(repo) + @client.issues(repo, 'closed')
        else
          issues=@client.issues(repo,issue_num)
        end
        issues=[issues] unless issues.class==Array

        #populate comments for each ticket
        
        #Rename the github issues values to syncableticket values
        issues=issues.each {|issue| issue.map {|key, value|
          key='created_on' if key=='created_at'
          key='label' if key=='labels'
          [key,value]
        }}

        #Creating SyncableTickets for Github Issue tickets is fairly
        #trivial, but this step may be more complicated for other bug trackers
        #when the API used doesn't return hash objects
        issues.map {|issue|
          SyncableTicket.new( issue.to_hash, @static_attributes )
        }
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
