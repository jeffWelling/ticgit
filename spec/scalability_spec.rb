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

  it "Should take the same amount of time to init on a large repo as a small one" do
    t1_before=0
    t1_after=0
    t2_before=0
    t2_after=0
    path1= setup_new_git_repo
    Dir.chdir( path1 ) do
      #test a small repo
      #do this a couple times to make it a bit fairer re caching
      10.times do
        t1_before=Time.now.to_i
        ticgit1=TicGitNG.open( path1, @orig_test_opts )
        t1_after=Time.now.to_i
      end
    end

    path2= setup_new_git_repo
    Dir.chdir( path2 ) do
      #test a large repo
      git=Git.open '.'
      500.times do |i|
        new_file("file_#{i}", "#{rand(9999999)}_#{i}")
        git.add "file_#{i}"
        git.commit "Added file_#{i}"
      end
      #do this a couple times to make it fairer re caching
      10.times do
        t2_before=Time.now.to_i
        ticgit2=TicGitNG.open( path2, @orig_test_opts )
        t2_after=Time.now.to_i
      end
    end
    #Opening is a simple operation, it should take less than a second in most cases,
    #But this test is intended to make sure that the size of the repo does not impact
    #the initialization time of TicGit-ng
    #FIXME Fix this dirty hack, find out what the proper way to do this is
    true.should == ((t1_after-t1_before) < 5)
    true.should == ((t2_after-t2_before) < 5)
  end

end
