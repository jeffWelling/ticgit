require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::Base do
  include TicGitNGSpecHelper

  before(:all) do
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
  end

  after(:all) do
    Dir.glob(File.expand_path("~/.ticgit-ng/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("~/.ticgit/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("/tmp/ticgit-ng-*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
  end

  it "should fail gracefully when init-ing if git has no commits" do
    tempdir = Dir.mktmpdir
    Dir.chdir(tempdir) do
      git = Git.init
    end
    opts=test_opts
    lambda {
      TicGitNG.open( tempdir, opts )
    }.should raise_error SystemExit
  end

  it "should have 4 ticket states" do
    @ticgitng.tic_states.size.should eql(4)
  end

  it "should be able to create new tickets" do
    @ticgitng.tickets.size.should eql(0)
    @ticgitng.ticket_new('my new ticket').should be_an_instance_of(TicGitNG::Ticket)
    @ticgitng.tickets.size.should eql(1)
  end

  it "should be able to list existing tickets" do
    @ticgitng.ticket_new('my second ticket').should be_an_instance_of(TicGitNG::Ticket)
    list = @ticgitng.ticket_list
    list.first.should be_an_instance_of(TicGitNG::Ticket)
    list.size.should eql(2)
  end

  it "should be able to change the state of a ticket" do
    tic = @ticgitng.ticket_list.first
    @ticgitng.ticket_change('resolved', tic.ticket_id)
    tic = @ticgitng.ticket_show(tic.ticket_id)
    tic.state.should eql('resolved')
  end

  it "should not be able to change the state of a ticket to something invalid" do
    tic = @ticgitng.ticket_list.first
    @ticgitng.ticket_change('resolve', tic.ticket_id)
    tic = @ticgitng.ticket_show(tic.ticket_id)
    tic.state.should_not eql('resolve')
  end

  it "should be able to change to whom the ticket is assigned" do
    tic = @ticgitng.ticket_list.first
    @ticgitng.ticket_assign('pope', tic.ticket_id)
    tic = @ticgitng.ticket_show(tic.ticket_id)
    tic.assigned.should eql('pope')
  end

  it "should not be able to change to whom the ticket is assigned if it is already assigned to that user" do
    tic = @ticgitng.ticket_list.first
    tic_id = tic.ticket_id
    lambda {
      @ticgitng.ticket_assign(tic.assigned, tic_id)
      @ticgitng.ticket_show(tic_id)
    }.should_not change(@ticgitng.ticket_recent(tic_id), :size)
  end

  it "should default to the current user when changing to whom the ticket is assigned" do
    tic = @ticgitng.ticket_list.first
    @ticgitng.ticket_checkout(tic.ticket_id)
    @ticgitng.ticket_assign()
    tic = @ticgitng.ticket_show(tic.ticket_id)
    tic.assigned.should eql(tic.email)
  end

  it "should only show open tickets by default" do
    @ticgitng.ticket_new('my third ticket')
    tics = @ticgitng.ticket_list
    states = tics.map { |t| t.state }.uniq
    states.size.should eql(1)
    states.first.should eql('open')
  end

  it "should be able to filter tickets on state" do
    tics = @ticgitng.ticket_list(:state => 'resolved')
    tics.size.should eql(1)
    tics = @ticgitng.ticket_list(:state => 'open')
    tics.size.should eql(2)
  end

  it "should be able to save and recall filtered ticket lists" do
    tics = @ticgitng.ticket_list(:state => 'resolved', :save => 'resolve')
    tics.size.should eql(1)
    rtics = @ticgitng.ticket_list(:saved => 'resolve')
    tics.size.should eql(1)
  end

  it "should be able to comment on tickets" do
    t = @ticgitng.ticket_new('my fourth ticket')
    t.comments.size.should eql(0)

    @ticgitng.ticket_comment('my new comment', t.ticket_id)
    t = @ticgitng.ticket_show(t.ticket_id)
    t.comments.size.should eql(1)
    t.comments.first.comment.should eql('my new comment')
  end

  it "should retrieve specific tickets" do
    tid = @ticgitng.ticket_list.last.ticket_id
    tic = @ticgitng.ticket_show(tid)
    tic.ticket_id.should eql(tid)
  end

  it "should be able to checkout a ticket" do
    tid = @ticgitng.ticket_list.last.ticket_id
    @ticgitng.ticket_checkout(tid)
    @ticgitng.ticket_show.ticket_id.should eql(tid)
  end

  it "should resolve partial shas into ticket" do
    tid = @ticgitng.ticket_list.last.ticket_id
    @ticgitng.ticket_checkout(tid[0, 5])
    @ticgitng.ticket_show.ticket_id.should eql(tid)

    @ticgitng.ticket_checkout(tid[0, 20])
    @ticgitng.ticket_show.ticket_id.should eql(tid)
  end

  it "should resolve order number from most recent list into ticket" do
    tics = @ticgitng.ticket_list(:state => 'open')
    @ticgitng.ticket_show('1').ticket_id.should eql(tics[0].ticket_id)
    @ticgitng.ticket_show('2').ticket_id.should eql(tics[1].ticket_id)
  end

  it "should be able to tag a ticket" do
    t = @ticgitng.ticket_list.last
    t.tags.size.should eql(0)
    @ticgitng.ticket_tag('newtag', t.ticket_id)
    t = @ticgitng.ticket_show(t.ticket_id)
    t.tags.size.should eql(1)
    t.tags.first.should eql('newtag')
  end

  it "should not be able to tag a ticket with a blank tag" do
    t = @ticgitng.ticket_new('my fourth ticket', :tags => [' '])
    t.tags.size.should eql(0)

    @ticgitng.ticket_tag(' ', t.ticket_id)
    t = @ticgitng.ticket_show(t.ticket_id)
    t.tags.size.should eql(0)

    @ticgitng.ticket_tag('', t.ticket_id)
    t = @ticgitng.ticket_show(t.ticket_id)
    t.tags.size.should eql(0)

    @ticgitng.ticket_tag(',mytag', t.ticket_id)
    t = @ticgitng.ticket_show(t.ticket_id)
    t.tags.size.should eql(1)
    t.tags.first.should eql('mytag')
  end

  it "should be able to remove a tag from a ticket" do
    t = @ticgitng.ticket_new('my next ticket', :tags => ['scotty', 'chacony'])
    t.tags.size.should eql(2)

    o=OpenStruct.new
    o.remove=true
    @ticgitng.ticket_tag('scotty', t.ticket_id, o)
    t.tags.size.should eql(2)
    t.tags.first.should eql('chacony')
  end

  it "should save state to disk after a new ticket" do
    time = File.lstat(@ticgitng.state).mtime.to_i
    sleep 1
    t = @ticgitng.ticket_new('my next ticket', :tags => ['scotty', 'chacony'])
    File.lstat(@ticgitng.state).mtime.to_i.should_not eql(time)
  end

  it "should be able to change the points of a ticket" do
    @ticgitng.ticket_new('my new ticket')
    tic = @ticgitng.ticket_list.first
    tic.state.should_not == 3
    @ticgitng.ticket_points(3, tic.ticket_id)
    tic = @ticgitng.ticket_show(tic.ticket_id)
    tic.points.should == 3
  end

  it "should detect the ticgit branch when the repository is moved" do
    #create git dir
      #done in before(:all) block
    #create some tickets
    tic=@ticgitng.ticket_new('my new ticket')
    #move the git dir
    FileUtils.mv( @path, @path+'1' )
    #test that the program does not raise SystemExit
    opts=test_opts
    opts[:init]=false
    lambda {
        @ticgitng=TicGitNG.open( @path+'1', opts )
    }.should_not raise_error SystemExit
  end

  it "should use the same email that git provides" do
    #This is necessary because the other specs depend
    #on the side effects of one another, but those 
    #side effects are detrimental to this spec so
    #we initialize things again for a clean slate.
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
    tic=@ticgitng.ticket_new('my new ticket')
    tic.email.should == @ticgitng.git.lib.config_get('user.email')
  end

  it "should be able to use '_' in assigning" do
    #This is necessary because the other specs depend
    #on the side effects of one another, but those
    #side effects are detrimental to this spec so
    #we initialize things again for a clean slate.
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
    tic=@ticgitng.ticket_new('my new ticket')
    tic=@ticgitng.ticket_assign( 'some_random_user', tic.ticket_id )
    tic=@ticgitng.ticket_show( tic.ticket_id )
    tic.assigned.should == 'some_random_user'
  end

  it "should return an updated ticket for each of the ticket_* methods" do
    #This is necessary because the other specs depend
    #on the side effects of one another, but those
    #side effects are detrimental to this spec so
    #we initialize things again for a clean slate.
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
    num_of_methods= @ticgitng.methods.collect {|m|
      m if m[/^ticket_/]
    }.compact.size.-(1).should == 12
    #ticket_new, ticket_points, ticket_tag
    ticket=@ticgitng.ticket_new('my new ticket')
    ticket.class.should == TicGitNG::Ticket
    ticket.title.should == 'my new ticket'
    ticket=@ticgitng.ticket_points( 1337, ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    ticket.points.should == 1337
    ticket=@ticgitng.ticket_tag( 'fubar', ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    ticket.tags.size.should == 1
    ticket.tags[0].should == 'fubar'
    #ticket_attach, ticket_get_attachment,
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        #attach the file
        ticket= @ticgitng.ticket_attach( attachment_fname, ticket.ticket_id )
        ticket.class.should == TicGitNG::Ticket
        ticket.attachments.size.should == 1
        ticket.attachments[0].attachment_name.should == 'fubar.txt'
        ticket= @ticgitng.ticket_get_attachment( 'fubar.txt', nil, ticket.ticket_id )
        ticket.class.should == TicGitNG::Ticket
        ticket.attachments.size.should == 1
        ticket.attachments[0].attachment_name.should == 'fubar.txt'
    end
    #ticket_assign, ticket_revparse,
    ticket=@ticgitng.ticket_assign( 'some_random_guy', ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    ticket.assigned.should == 'some_random_guy'
    ticket1=@ticgitng.ticket_revparse( ticket.ticket_id[/[0-9a-z]{5}/] )
    ticket1.should == ticket.ticket_name
    #ticket_change, ticket_show,
    ticket=@ticgitng.ticket_change( 'resolved', ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    ticket.state.should == 'resolved'
    @ticgitng.ticket_change( 'open', ticket.ticket_id )
    ticket=@ticgitng.ticket_show( ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    #ticket_checkout, ticket_list,
    ticket=@ticgitng.ticket_checkout( ticket.ticket_id )
    ticket.class.should == TicGitNG::Ticket
    @ticgitng.current_ticket.should == ticket.ticket_name
    tickets=@ticgitng.ticket_list
    tickets.size.should == 1
    tickets[0].class.should == TicGitNG::Ticket
    tickets[0].ticket_id.should == ticket.ticket_id
    #ticket_comment
    ticket=@ticgitng.ticket_comment( 'fubar fubar fubar', ticket.ticket_id )
    ticket.comments[0].comment.should == 'fubar fubar fubar'
  end
  
  it "the comment_id should match on a new comment when its re-read"

end
