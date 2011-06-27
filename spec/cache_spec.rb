require File.dirname(__FILE__) + "/spec_helper"
require 'pp'

describe TicGitNG do
  include TicGitNGSpecHelper
  include TicGitNG

  before(:each) do
    @path= setup_new_git_repo
    @orig_test_opts= test_opts
    @ticgitng= TicGitNG.open(@path, @orig_test_opts)
  end

  after(:each) do
    Dir.glob(File.expand_path("~/.ticgit-ng/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("~/.ticgit/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("/tmp/ticgit-ng-*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
  end

  it "Should not contaminate ticgit/ticgit-ng branch just because working dir is contaminated" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
      @ticgitng.ticket_new('new ticket, clean state', :comment=>"I am the content")
      workingdir_ticket=File.join( @ticgitng.tic_working, @ticgitng.tickets.sort[0][0] )
      new_file( File.join(workingdir_ticket, 'fake_file'), 'I am a file that should not be commited' )
      @ticgitng.ticket_new('another ticket', :comment=>"This commit should not add the new_file()" )
      #@ticgitng.git.gtree(@ticgitng.which_branch?).trees.map {|dir_name| dir_name.include?('fake_file') }.size.should eq(2)
      has_fake_file=false
      @ticgitng.git.gtree(@ticgitng.which_branch?).trees.each {|tree| tree[1].blobs.map {|blob_name| has_fake_file=true if blob_name[0].include?('fake_file') }}
      has_fake_file.should eq(false)
    end

  end

end
