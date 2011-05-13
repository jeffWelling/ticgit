require 'octopi'

module TicGitNG
  module Sync
    class Github_Issues < GenericBugtracker
      include Octopi
      def initialize(options={})
        @options=options
        #:malleable attributes are those which can be directly updated instead of using # comments
        #:static attributes
        @attr_info={:malleable=>%w(title body comments updated_at label),
                    :static=>%w(user repository github_id created_at gravatar_id html_url)}
      end
      attr_reader :attr_info

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
          SyncableTicket.new( hashify(issue), @attr_info )
        }
      end
      
      #update() is passed a SyncableTicket, and updates the associated 
      #Github Issues ticket with the values that have changed in SyncableTicket
      #Do not worry about having to properly synchronize tickets, this is done 
      #at a higher level. update() is only called to update the associated ticket
      #with new values.
      def update repo, ticket
        unless ticket.github_id
          raise "Cannot update ticket without github_id" 
        end

        #read ticket from github so we can tell which fields need updating
        external_ticket= read( repo, ticket.github_id )

        #check title,body
        unless (ticket.title == external_ticket.body && ticket.body == external_ticket.body)
          authenticated_with :login=>@options[:username], :token=>@options[:token] do
            issue=Issue.find(:user=>get_username(repo),:repo=>get_repo(repo),:number=>ticket.github_id)
            issue.title = ticket.title
            issue.body = ticket.body
            issue.save
          end
        end
        
        #check state
        unless (ticket.state == external_ticket.state)
          authenticated_with :login=>@options[:username], :token=>@options[:token] do
            issue=Issue.find(:user=>get_username(repo),:repo=>get_repo(repo),:number=>title.github_id)
            if external_ticket.state == "open"
              issue.close!
            else
              issue.reopen!
            end
          end
        end
        
        #check labels
        #FIXME the authenticated_with section looks like it can be broken out into it's own method to reduce
        #duplicate code
        unless (ticket.label == external_ticket.label)
          #Add labels from ticket to external_ticket
          unless (labels_to_update=ticket.label.collect {|i| external_ticket.label.include?(i) ? nil : i }.compact).empty?
            authenticated_with :login=>@options[:username], :token=>@options[:token] do
              issue=Issue.find(:user=>get_username(repo),:repo=>get_repo(repo),:number=>title.github_id)
              #I was going to try to add all of the labels in one call, but Octopi breaks it up into one API
              #call per label anyway so it would be a wasted effort
              labels_to_update.each {|label| issue.add_label(label) }
            end
          end
          #Remove labels on external_ticket which are not on ticket
          unless (labels_to_update=external_ticket.label.collect {|i| ticket.label.include?(i) ? nil : i }.compact).empty?
            authenticated_with :login=>@options[:username], :token=>@options[:token] do
              issue=Issue.find(:user=>get_username(repo),:repo=>get_repo(repo),:number=>title.github_id)
              labels_to_update.each {|label| issue.remove_label(label) }
            end
          end
        end

        #check comment_body
        
        x=eval("fubar")

        #ticgit_ticket.title="fubar"
        #ticgit_ticket.body="fubar fubar fubar"
        #ticket=ticgit_ticket
        #
        #
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
            :created_by=> issue.user,
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
              :comment_github_id          =>comment.id,
              :comment_updated_on         =>comment.updated_at}
            }
        }
      end
    end
  end
end
