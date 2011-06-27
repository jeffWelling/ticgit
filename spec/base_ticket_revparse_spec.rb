require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::Base do
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

  it "should return a ticket by index" do
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
    test_titles = ["0", "1", "2"]
    test_titles.each do |title|
      @ticgitng.ticket_new(title)
    end

    # This forces the ticket list to cache as an indexable list
    # Use the middle ticket as our test ticket
    title_index = @ticgitng.ticket_list[1].title.to_i

    # Ticket indexing is 1 based. Query for the middle ticket.
    found_tic_name = @ticgitng.ticket_revparse("2")
    clean_name = test_titles[title_index].downcase.gsub(/[^a-z0-9]+/i, '-')
    found_tic_name.should match /^\d+_#{clean_name}_\d+$/
  end

  it "should return a ticket by full SHA" do
    test_title = "My SHA test ticket"
    tic = @ticgitng.ticket_new(test_title)

    found_tic_name = @ticgitng.ticket_revparse(tic.ticket_id)
    clean_name = test_title.downcase.gsub(/[^a-z0-9]+/i, '-')
    found_tic_name.should match /^\d+_#{clean_name}_\d+$/
  end

  it "should return a ticket by partial SHA which is an integer" do
    test_title = "My partial integer SHA test ticket"
    integer_partial_sha = '432513'

    clean_name = test_title.downcase.gsub(/[^a-z0-9]+/i, '-')
    @ticgitng.should_receive(:read_tickets).with().and_return(
      {
        "1306092232_#{clean_name}_317" =>
          {
            "files"=> [
                ["ASSIGNED_some_person@email.com", "2d4e94d6963e02f079bc5712ed90a8237a415ebf"],
                ["STATE_open", "f510327578a4562e26a7c64bdf061e4a49f85ee6"],
                ["TICKET_ID", integer_partial_sha+'ajf34j2lk23bk3423'],
                ["TICKET_TITLE", "44c496d5543823f54e7920738b70b03e85955866"],
                ["TITLE", "44c496d5543823f54e7920738b70b03e85955866"]
            ]
          }
      }
    )

    found_tic_name = @ticgitng.ticket_revparse(integer_partial_sha)
    found_tic_name.should match /^\d+_#{clean_name}_\d+$/
  end

  it "should return a ticket by partial SHA" do
    test_title = "My partial SHA test ticket"
    tic = @ticgitng.ticket_new(test_title)

    found_tic_name = @ticgitng.ticket_revparse(tic.ticket_id[0..5])
    clean_name = test_title.downcase.gsub(/[^a-z0-9]+/i, '-')
    found_tic_name.should match /^\d+_#{clean_name}_\d+$/
  end

  it "should not return a ticket by short partial SHA" do
    tic = @ticgitng.ticket_new("My short partial SHA test ticket")

    found_tic_name = @ticgitng.ticket_revparse( tic.ticket_id[0..3] )
    found_tic_name.should == nil
  end

end
