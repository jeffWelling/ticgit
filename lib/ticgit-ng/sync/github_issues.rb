require 'octokit'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      def initialize(options={})
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
       
        clienty=Octokit::Client.new( { :username => 'jeffWelling', :token => `git config github.token`.strip } )
        #The Github API only returns tickets with the state 'open' by default, so to get
        #all tickets we have to query twice. Unless we're only looking for one ticket.
        if issue_num.nil? 
          issues=(clienty.issues(repo)) + (clienty.issues(repo, 'closed'))
        else
          issues=clienty.issues(repo,issue_num)
        end
        issues=[issues] unless issues.class==Array

        #populate comments for each ticket
        issues.each_index {|issues_num|
          issues[issues_num]['comments']= clienty.issue_comments(repo, issues[issues_num].number)
        }
        
        #Rename the github issues values to syncableticket values
        issues.map! {|issue| 
          issue=issue.to_hash
          issue['comments'].map! {|comment| comment.to_hash }

          issue.merge!( {:created_on=>issue['created_at'], :label=>issue['labels']} )
          issue['comments'].map! {|comment|
            comment.merge!( {:comment_created_on=>comment['created_at'],
                           :comment_author=> comment['user'],
                           :comment_body=> comment['body']} )
          }
          issue
        }

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
