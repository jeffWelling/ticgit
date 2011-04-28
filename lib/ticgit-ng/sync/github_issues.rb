require 'octopi'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      include Octopi
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

        issues=nil
        auth=TicGitNG::Sync.get_auth_info
        authenticated_with :login=>auth[:username], :token=>auth[:token] do
          if issue_num.nil?
            issues=Issue.find_all( :user=> get_username(repo), :repo=> get_repo_name(repo), :state=>'open' )
            issues+= Issue.find_all( :user=> get_username(repo), :repo=> get_repo_name(repo), :state=>'closed' )
          else
            issues=[Issue.find(:user=> get_username(repo), :repo=> get_repo_name(repo), :state=>'closed' )]
          end
        end
        
        #Creating SyncableTickets for Github Issue tickets is fairly
        #trivial, but this step may be more complicated for other bug trackers
        #when the API used doesn't return hash objects
        issues.map {|issue|
          next unless issue.class==Octopi::Issue
          SyncableTicket.new( {
            :body=>       issue.body,
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
          }, @static_attributes )
        }
      end
      
      def update
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
    end
  end
end
