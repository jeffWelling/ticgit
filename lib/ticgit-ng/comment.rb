module TicGitNG
  class Comment
    attr_accessor :base, :user, :added, :comment, :comment_id

    def initialize( c, user, filename, time=nil )
      raise unless c
      unless c.class==String and user.class==String and filename.class==String and (time.class==NilClass or time.class==Time)
        raise "Comment.new: invalid paramaters -- #{c.class}, #{user.class}, #{filename.class}, #{time.class}"
      end
      @comment= c
      @user=user
      @added= time.nil? ? Time.now : time
      #FIXME 
      #The comment_id is determined from the filename (and not the hash of the file itself)
      #because when TicGit-ng is patched to allow editing comments, the comments file will change
      #and this means the hash of the file changes. If your using said hash as an ID, your comment ID
      #would change whenever the comment changed, and we want a comment ID that is immutable per 
      #comment.
      @comment_id=Digest::SHA1.new.update(filename).hexdigest
      self
    end

    def self.read( base, file_name, sha )
      type, date, user = file_name.split('_')

      new( (base.git.gblob(sha).contents rescue nil), user, Time.at(date.to_i) )
    end
  end
end
