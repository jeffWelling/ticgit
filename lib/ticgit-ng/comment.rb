module TicGitNG
  class Comment

    attr_reader :base, :user, :added, :comment, :comment_id

    def initialize(base, file_name, sha)
      @base = base
      @comment = base.git.gblob(sha).contents rescue nil

      #The comment_id is determined from the filename (and not the hash of the file itself)
      #because when TicGit-ng is patched to allow editing comments, the comments file will change
      #and this means the hash of the file changes. If your using said hash as an ID, your comment ID
      #would change whenever the comment changed, and we want a comment ID that is immutable per 
      #comment.
      if @comment_id=@comment[/#ID=[a-z0-9]{40}$/]
        #There is a '#ID=...' string at the end of the comment which contains the comment ID
        @comment_id=@comment_id.gsub('#ID=','')
      else
        #There is no ID appended to the filename, this comment was likely created with an
        #old version of TicGit
        #Determine comment_id from filename
        @comment_id= sha1(file_name)
      end

      type, date, user = file_name.split('_')

      @added = Time.at(date.to_i)
      @user = user

    end

    def sha1 string
      raise "sha1(string): string must be a String" unless string.class==String
      Digest::SHA1.new.update(string).hexdigest
    end
  end
end
