require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::CLI do
  include TicGitNGSpecHelper

  before(:each) do
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
  end

  after(:each) do
    Dir.glob(File.expand_path("~/.ticgit-ng/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("~/.ticgit/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("/tmp/ticgit-ng-*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
  end

  it "should list the tickets" do
    @ticgitng.tickets.size.should eql(0)
    @ticgitng.ticket_new('my new ticket').should be_an_instance_of(TicGitNG::Ticket)
    @ticgitng.ticket_new('my second ticket').should be_an_instance_of(TicGitNG::Ticket)
    @ticgitng.tickets.size.should eql(2)
    fields = %w[TicId Title State Date Assgn Tags]
    output = []
    # It's unclear why it's necessary to append each line like this, but
    # cli('list') would otherwise return nil. The spec helper probably
    # needs some refactoring.
    cli(@path, 'init','list') do |line|
      output << line
    end
    output.shift.should match ""
    output.shift.should match /#{fields.join( '\s+' )}/
    output.shift.should match /^-+$/
    #check that at least the SHA1 prefix exists
    output.shift[/^[a-z0-9]{6}\s/].should_not == nil
    output.shift[/^[a-z0-9]{6}\s/].should_not == nil
    output.shift.should match ""
  end

  it "should return the same ticket from ticket_show and ticket_new" do
      #FIXME the output of cli(@path,'list') produces a random order
      #- This has to do with a lack of timeskew
      20.times do
        #setup git repo
        git_dir= setup_new_git_repo
        base= TicGitNG.open( git_dir, test_opts )
        base.tickets.size.should eql(0)

        tic1=base.ticket_new('my new ticket', Hash.new, t1=time_skew)
        tic1.should be_an_instance_of(TicGitNG::Ticket)
        tic1.should == base.ticket_show( tic1.ticket_id )

        tic2=base.ticket_new('my second ticket', Hash.new, t2=time_skew)
        tic2.should be_an_instance_of(TicGitNG::Ticket)
        tic2.should == base.ticket_show( tic2.ticket_id )

        tic1.should_not == tic2
        tic1.should_not == base.ticket_show( tic2.ticket_id )

        tic1.title.should == 'my new ticket'
        tic2.title.should == 'my second ticket'
        base.tickets.size.should eql(2)

        if t1>t2
            t=tic2
            tic2=tic1
            tic1=t
        end

        fields = %w[TicId Title State Date Assgn Tags]
        output = []
        # It's unclear why it's necessary to append each line like this, but
        # cli('list') would otherwise return nil. The spec helper probably
        # needs some refactoring.
        cli(git_dir, 'init','list') do |line|
          output << line
        end
        output.shift.should match ""
        output.shift.should match /#{fields.join( '\s+' )}/
        output.shift.should match /^-+$/

        #first ticket
        line=output.shift.split(' ')
        line[0].should match /^[a-z0-9]{6}/
        #This doesn't hinge on t1<t2 because assigned will be
        # the same for both tickets
        a=tic1.assigned
        if a.bytesize > 8
            a="#{a[0, 7]}+"
        end
        line.pop.should == a
        #FIXME if t1<t2, t1, else, t2
        line.pop.should == tic1.opened.strftime('%m/%d')
        line.pop.should == 'open'
        #delete the sha1
        line.shift
        line.join(' ').should == tic1.title

        #second ticket
        line=output.shift.split(' ')
        line[0].should match /^[a-z0-9]{6}/
        a=tic2.assigned
        if a.bytesize > 8
            a="#{a[0, 7]}+"
        end
        line.pop.should == a
        line.pop.should == tic2.opened.strftime('%m/%d')
        line.pop.should == 'open'
        #delete the sha1
        line.shift
        line.join(' ').should == tic2.title
      end
  end

  it "should show a ticket" do
    #FIXME needs time_sku to avoid random failures
    @ticgitng.tickets.size.should eql(0)

    tic1=@ticgitng.ticket_new('my new ticket', Hash.new, t1=time_skew)
    tic1.should be_an_instance_of(TicGitNG::Ticket)
    tic1=@ticgitng.ticket_show(tic1.ticket_id)

    tic2=@ticgitng.ticket_new('my second ticket', Hash.new, t2=time_skew)
    tic2.should be_an_instance_of(TicGitNG::Ticket)
    tic2=@ticgitng.ticket_show(tic2.ticket_id)

    @ticgitng.tickets.size.should eql(2)
    if t1>t2
        t=tic2
        tic2=tic1
        tic1=t
    end

    fields = %w[TicId Title State Date Assgn Tags]
    output = []
    # It's unclear why it's necessary to append each line like this, but
    # cli('list') would otherwise return nil. The spec helper probably
    # needs some refactoring.
    cli(@path, 'init','list') do |line|
      output << line
    end
    output.shift.should match ""
    output.shift.should match /#{fields.join( '\s+' )}/
    output.shift.should match /^-+$/

    #first ticket
    line=output.shift.split(' ')
    line[0].should match /^[a-z0-9]{6}/
    a=tic1.assigned
    if a.bytesize > 8
        a="#{a[0, 7]}+"
    end
    line.pop.should == a
    line.pop.should == tic1.opened.strftime('%m/%d')
    line.pop.should == 'open'
    #delete the sha1
    line.shift
    line.join(' ').should == tic1.title

    #second ticket
    line=output.shift.split(' ')
    line[0].should match /^[a-z0-9]{6}/
    a=tic2.assigned
    if a.bytesize > 8
        a="#{a[0, 7]}+"
    end
    line.pop.should == a
    line.pop.should == tic2.opened.strftime('%m/%d')
    line.pop.should == 'open'
    #delete the sha1
    line.shift
    line.join(' ').should == tic2.title
  end

  it 'displays --help' do
    expected = format_expected(<<-OUT)
Please specify at least one action to execute.

Usage: ti COMMAND [FLAGS] [ARGS]

The available ticgit commands are:
    assign                           Assigns a ticket to someone
    attach                           Attach file to ticket
    checkout                         Checkout a ticket
    comment                          Comment on a ticket
    help                             Show help for a ticgit command
    init                             Initialize Ticgit-ng
    list                             List tickets
    new                              Create a new ticket
    points                           Assign points to a ticket
    recent                           List recent activities
    show                             Show a ticket
    state                            Change state of a ticket
    sync                             Sync tickets
    tag                              Modify tags of a ticket
    title                            Modify the title of a ticket

Common options:
    -v, --version                    Show the version number
    -h, --help                       Display this help
    OUT

    cli(@path) do |line|
      line.should == expected.shift
    end
  end

  it 'displays empty list' do
    fields = %w[TicId Title State Date Assgn Tags]
    output = []
    # It's unclear why it's necessary to append each line like this, but
    # cli('list') would otherwise return nil. The spec helper probably
    # needs some refactoring.
    cli(@path, 'init','list') do |line|
      output << line
    end
    output.shift.should match ""
    output.shift.should match /#{fields.join '\s+'}/
    output.shift.should match /^-+$/
  end
end
