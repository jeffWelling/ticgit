module TicGitNG
    class Attachment
        attr_reader :user, :added, :filename, :sha, :attachment_name
        attr_reader :original_filename
        alias :read :initialize

        def initialize( fname )
            #FIXME expect fname to be a raw filename that needs to be converted
            #      into a properly formatted ticket name
            @filename=fname
            trailing_underscore= File.basename(fname)[/_$/] ? true : false
            trailing_underscore=false
            temp=File.basename(fname).split('_').reverse
            @added=Time.at(temp.pop.to_i)
            @user= temp.pop
            @attachment_name= temp.reverse.join('_')
            if trailing_underscore
              @attachment_name << '_'
            end
        end

        #Called when attaching a new attachment and when reading/opening attachments
        #FIXME Make a 'read' and 'create' function to differentiate between
        #      between creation of a ticket and reading an existing ticket.
        def self.create raw_fname, ticket, time 
            #Attachment naming format:
            #ticket_name/ATTACHMENTS/123456_jeff.welling@gmail.com_fubar.jpg
            #raw_fname "/home/guy/Desktop/fubar.jpg"

            #create attachment dir if first run
            a_name= File.expand_path( File.join(
                File.join( ticket.ticket_name, 'ATTACHMENTS' ), 
                ticket.create_attachment_name(raw_fname, time)
            ))
            #create new filename from ticket
            if File.exist?( File.dirname( a_name )  ) && 
               !File.directory?( File.dirname(a_name) )

                puts "Could not create ATTACHMENTS directory"
                exit 1
            elsif !File.exist?( File.dirname( a_name ) )
                Dir.mkdir File.dirname( a_name )
            end
            #copy/link the raw_filename
            Dir.chdir( File.dirname(a_name) ) do
                FileUtils.cp( raw_fname, a_name )
            end
            #call init on the new file to properly populate the variables
            a_name= File.join( 
                              File.basename( File.dirname( a_name ) ),
                              File.basename( a_name )
                             )
            return Attachment.new( a_name )
        end
    end
end
