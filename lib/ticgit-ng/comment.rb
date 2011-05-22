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
      @comment_id=Digest::SHA1.new.update(file_name).hexdigest

      type, date, user = file_name.split('_')

      @added = Time.at(date.to_i)
      @user = user

    end
  end
end
