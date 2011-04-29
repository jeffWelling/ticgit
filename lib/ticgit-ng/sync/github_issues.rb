require 'octopi'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      include Octopi
      def initialize(options={})
        @options=options
        @static_attributes=%w(created_at gravatar_id html_url)
      end
      attr_reader :static_attributes

      #create a new issue
      #to create a comment on an existing issue, use update()
      def create( title, body )
        raise "Github_Issues.create(title,body): title and body must be strings" unless
          title.class==String and body.class==String

        issue=nil
        authenticated_with :login=>@options[:user], :token=>@options[:token] do
          hashify Issue.open( :user=>get_username(@options[:repo]), :repo=>get_repo_name(@options[:repo]),
                           :params=>{:title=>title,:body=>body} )
        end

      end
      
      #read all issues in repo if issue_num.nil?
      #read issue_num in repo if issue_num.class==Fixnum
      def read( repo=nil, issue_num=nil )
        raise "read(repo,issue_num): issue must be nil or integer" unless
          issue_num.nil? or issue_num.class==Fixnum

        issues=nil
        user= repo.nil? ? get_username(@options[:repo]) : get_username(repo)
        repo= repo.nil? ? get_repo_name(@options[:repo]): get_repo_name(repo)
        authenticated_with :login=>@options[:username], :token=>@options[:token] do
          if issue_num.nil?
            issues=Issue.find_all( :user=> user, :repo=> repo, :state=>'open' )
            issues+= Issue.find_all( :user=> user, :repo=> repo, :state=>'closed' )
          else
            issues=[Issue.find(:user=> user, :repo=> repo, :number=>issue_num )]
          end
        end
        
        #Creating SyncableTickets for Github Issue tickets is fairly
        #trivial, but this step may be more complicated for other bug trackers
        #when the API used doesn't return hash objects
        issues.map {|issue|
          next unless issue.class==Octopi::Issue
          SyncableTicket.new( hashify(issue), @static_attributes )
        }
      end
      
      #Receives a SyncableTicket and synchronizes it with the existing
      #version of the same ticket in Github Issues
      #When writing your own version, don't forget to use comments for any
      #attributes which can't be updated.
      def update ticket
      end
      
      def destroy
      end

      private

      def get_username source
        source[/^[^\/]*/]
      end

      def get_repo_name source
        source[/[^\/]*$/]
      end

      def hashify issue
        {   :body=>       issue.body,
            :created_on=> issue.created_at,
            :label=>      issue.labels,
            :github_id=>  issue.number,
            :repository=> issue.repository.to_s,
            :state=>      issue.state,
            :title=>      issue.title,
            :updated_at=> issue.updated_at,
            :user=>       issue.user,
            :votes=>      issue.votes,
            :comments=>   issue.comments.map {|comment|
             {:comment_body               =>comment.body,
              :comment_author             =>comment.user,
              :comment_created_on         =>comment.created_at,
              :comment_author_gravatar_id =>comment.gravatar_id,
              :comment_id                 =>comment.id,
              :comment_updated_on         =>comment.updated_at}
            }
        }
      end
    end
  end
end
