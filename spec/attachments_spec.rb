require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::Attachment do
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
  #To make sure attachments[] isn't loaded randomly and that we're aren't just getting 
  #lucky this time around, run the test 100 times in a loop.
  it "should sort attachments[] chronologically, not randomly" do
      #FIXME implementation failure
      #Does not properly detect randomized loads
      #Test with and without TicGitNG.open
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
      5.times do
          #setup git repo
          git_dir= setup_new_git_repo
          base= TicGitNG.open( git_dir, test_opts )
          #add ticket
          tic= base.ticket_new('new ticket')
          #add 5 attachments
          5.times do |i|
              #FIXME attahcments must not be added at the exact same time
              attachment_fname= File.join( Dir.mktmpdir('to_attach'), "fubar.txt#{i}" ) 
              new_file( attachment_fname, "content#{i}" )
              tic= base.ticket_attach( attachment_fname, tic.ticket_id, time_skew() )
          end
          tic.attachments.size.should == 5
          #re-read the ticket to read the attachments
          #check the sort
          last=nil
          tic.attachments.each {|a|
              unless last.nil?
                  a.added.should >= last.added
              end
              last=a
          }
          base= TicGitNG.open( git_dir, test_opts )
          #check attachments are in order
          tic= base.ticket_show( tic.ticket_id )
          #check the sort
          last=nil
          tic.attachments.each {|a|
              unless last.nil?
                  a.added.should >= last.added
              end
              last=a
          }
      end
    end
  end

  it "should be able to add an attachment to a ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname, tic.ticket_id ) 
        #check that the file was attached
        tic.attachments.map {|a|
            a.filename.split('_').pop=='fubar.txt'
        }.index( true ).should_not == nil
    end
  end

  it "should support multiple attachments per ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname1=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        new_file( attachment_fname2=File.join( to_attach, 'fubar.jpg' ), "More contents!" )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id ) 
        tic= @ticgitng.ticket_attach( attachment_fname2, tic.ticket_id )
        tic= @ticgitng.ticket_show( tic.ticket_id )
        #check that the file was attached
        cond_1=false
        cond_2=false
        tic.attachments.map {|a|
            if a.filename.split('_').pop=='fubar.txt'
                cond_1=true
            elsif a.filename.split('_').pop=='fubar.jpg'
                cond_2=true
            end
        }
        [cond_1,cond_2].uniq.size.should == 1
        cond_1.should == true
    end
  end
  it "should be able to see an attachment that has been added to a ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        contents="I am the contents of the attachment"
        new_file( attachment_fname=File.join( to_attach, 'fubar.txt' ), contents )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname, tic.ticket_id ) 
        #check that the file was attached with details
        tic.attachments.size.should == 1
        tic.attachments[0].attachment_name.should == 'fubar.txt'
        tic.email.should == tic.attachments[0].user
        tic.base.in_branch do |wd|
            read_line_of(File.join( tic.ticket_name, tic.attachments[0].filename)).strip.should == contents 
        end
    end
  end
  it "should be able to get the attachment based on 'AttachmentID'" do     #AttachmentID is a number
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        #FIXME time_skew randomizes the ordering of the attachments
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i+500)
        #get attachment
        new_filename0= File.join( 
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.txt' )
        new_filename1= File.join( 
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.jpg' )
        #check contents
        @ticgitng.ticket_get_attachment( 0, new_filename0, tic.ticket_id )
        File.exist?( new_filename0 ).should == true
        read_line_of( new_filename0 ).strip.should == content0
        @ticgitng.ticket_get_attachment( 1, new_filename1, tic.ticket_id )
        File.exist?( new_filename1 ).should == true
        read_line_of( new_filename1 ).strip.should == content1
    end
  end

  it "should be able to get the attachment based on filename" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id )
        #get attachment
        new_filename0= File.join( 
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.txt' )
        new_filename1= File.join(
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.jpg' )
        #check contents
        @ticgitng.ticket_get_attachment( 'fubar.txt', new_filename0, tic.ticket_id )
        #test getting a file to a directory by specifying new-filename as a directory
        @ticgitng.ticket_get_attachment( 'fubar.txt', File.dirname(new_filename0), tic.ticket_id )
        File.exist?( new_filename0 ).should == true
        File.exist?( File.join(File.dirname(new_filename0), 'fubar.txt') ).should==true
        read_line_of( new_filename0 ).strip.should == content0
        read_line_of( File.join(File.dirname(new_filename0), 'fubar.txt') ).strip.should == content0
        @ticgitng.ticket_get_attachment( 'fubar.jpg', new_filename1, tic.ticket_id )
        #test getting a file to a directory by specifying new-filename as a directory
        @ticgitng.ticket_get_attachment( 'fubar.jpg', File.dirname(new_filename1), tic.ticket_id )
        File.exist?( new_filename1 ).should == true
        File.exist?( File.join(File.dirname(new_filename1), 'fubar.jpg' ) ).should==true
        read_line_of( new_filename1 ).strip.should == content1
        read_line_of( File.join(File.dirname(new_filename1), 'fubar.jpg') ).strip.should==content1
    end
  end
  it "should only have valid filenames that begin with 'ATTACHMENTS/'" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i + 60)
        tic.attachments.each {|a| a.filename[/^ATTACHMENTS\//].nil?.should == false }
    end
  end
  it "should be able to list the attachments on the current ticket" do  #`ti attach list`
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i+60 )
        tic.attachments.size.should == 2
        tic.attachments[0].attachment_name.should == 'fubar.txt'
        tic.attachments[1].attachment_name.should == 'fubar.jpg'
        tic.attachments[0].user.should_not == nil
        tic.attachments[1].user.should_not == nil
    end
  end
  it "should not change the attachment that has been attached if the local file changes" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i+60 )
        File.open( attachment_fname0, 'a' ) {|f|
            f.puts "I am a second line in the first attachment!"
        }
        File.open( attachment_fname1, 'a' ) {|f|
            f.puts "I am a second line in the second attachment!"
        }
        tic.base.in_branch {|wd|
            File.read( File.join( 
                                 tic.ticket_name,
                                 tic.attachments[0].filename 
                                )
                     ).strip.split("\n").size.should==1
            File.read( File.join(
                                 tic.ticket_name,
                                 tic.attachments[1].filename 
                                )
                     ).strip.split("\n").size.should==1
        }
        File.read( attachment_fname0 ).strip.split("\n").size.should==2
        File.read( attachment_fname1 ).strip.split("\n").size.should==2
        #FIXME checkout the attachments to see if they have changed
    end
  end
  it "should not explode violently when retrieving an attachment from no attachments" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        lambda {
            tic.attachments[0]
        }.should_not raise_error
        lambda {
            @ticgitng.ticket_get_attachment( 0, nil, tic.ticket_id )
        }.should raise_error(SystemExit)
    end
  end
  it "should be able to handle filenames with '_' in them -- '_' is a special char" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        #Split the attachment basename, delete the first two (time,user), remianing is filename
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        new_file( attachment_fname0=File.join( to_attach, 'fu_bar.txt' ), content0 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic.attachments[0].attachment_name.should == 'fu_bar.txt'
    end
  end
  it "should allow the attaching of multiple filenames with the same name" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.jpg' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i+60 )
        tic.attachments[0].attachment_name.should == 'fubar.jpg'
        tic.attachments[1].attachment_name.should == 'fubar.jpg'
    end
  end
  it "should not explode violently when a duplicate file is attached" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        new_file( attachment_fname0=File.join( to_attach, 'fubar.jpg' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content0 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id, Time.now.to_i ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id, Time.now.to_i+60 )
        tic.attachments[0].attachment_name.should == 'fubar.jpg'
        tic.attachments[1].attachment_name.should == 'fubar.jpg'
    end
  end
  it "should be able to properly get attachments with '_' in the filename" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        # a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        content0="I am the contents of the attachment"
        content1="More contents!"
        new_file( attachment_fname0=File.join( to_attach, 'fu_bar_baz_ted_zim.txt' ), content0 )
        new_file( attachment_fname1=File.join( to_attach, 'fu_bar_baz_ted_zim*$@#.jpg' ), content1 )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id ) 
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id )
        #get attachment
        new_filename0= File.join( 
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.txt' )
        new_filename1= File.join(
            File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
            'new_filename.jpg' )
        #check contents
        @ticgitng.ticket_get_attachment( 'fu_bar_baz_ted_zim.txt', new_filename0, tic.ticket_id )
        @ticgitng.ticket_get_attachment( 'fu_bar_baz_ted_zim.txt', File.dirname(new_filename0), tic.ticket_id )
        File.exist?( new_filename0 ).should == true
        File.exist?( File.join(File.dirname(new_filename0), 'fu_bar_baz_ted_zim.txt') ).should==true
        @ticgitng.ticket_get_attachment( 'fu_bar_baz_ted_zim*$@#.jpg', new_filename1, tic.ticket_id )
        @ticgitng.ticket_get_attachment( 'fu_bar_baz_ted_zim*$@#.jpg', File.dirname(new_filename1), tic.ticket_id )
        File.exist?( new_filename1 ).should == true
        File.exist?( File.join(File.dirname(new_filename1), 'fu_bar_baz_ted_zim*$@#.jpg' ) ).should==true
    end
  end
  it "should fail gracefully when trying to get a filename that does not exist" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
      lambda {
          tic= @ticgitng.ticket_new('my_delicious_ticket')
          # a file to attach
          to_attach= Dir.mktmpdir('to_attach')
          content0="I am the contents of the attachment"
          content1="More contents!"
          new_file( attachment_fname0=File.join( to_attach, 'fubar.txt' ), content0 )
          new_file( attachment_fname1=File.join( to_attach, 'fubar.jpg' ), content1 )
          #attach the file
          tic= @ticgitng.ticket_attach( attachment_fname0, tic.ticket_id )
          tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id )
          #get attachment
          new_filename0= File.join(
              File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
              'new_filename.txt' )
          new_filename1= File.join(
              File.expand_path(Dir.mktmpdir('ticgit-ng-get_attachment-test')),
              'new_filename.jpg' )
          #check contents
          @ticgitng.ticket_get_attachment( 'fake_file.txt', new_filename0, tic.ticket_id )
        }.should raise_error SystemExit
    end
  end
end
