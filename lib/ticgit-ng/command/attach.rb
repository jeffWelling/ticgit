module TicGitNG
    module Command
        # Attach a file to a ticket
        #
        # Usage:
        # ti attach                             
        # (print help for 'ti attach')
        #
        # ti attach {filename}
        # (attach {filename} to current ticket)
        #
        # ti attach -i {ID} {filename}          
        # (attach file {filename} to ticket with ID {ID})
        #
        # ti attach -g {f_id}
        # (retrieve attached file {f_id}, place in current dir}
        #
        # ti attach -g {f_id} -n {new_filename}
        # (retrieve attached file {f_id}, place as {new_filename})
        module Attach
            def parser(opts)
                opts.banner = "Usage: ti attach [options] [filename]"

                opts.on_head(
                    "-i TICKET_ID", "--id TICKET_ID", "Attach the file to this ticket"){|v|
                    options.ticket_id = v
                }
                opts.on_head(
                    "-g FILE_ID", "--get FILE_ID", "Retrieve the file FILE_ID"){|v|
                    puts "Warning: ticket ID argument is not valid with the retrieve attachment argument" if options.ticket_id
                    options.get_file = v
                }
                opts.on_head(
                    "-n N_FILENAME", "--new-filename", "Use this filename for the retrieved attachment"){|v|
                    raise ArgumentError, "Error: New filename argument is only valid with the retrieve arrachment argument" unless options.get_file
                    options.new_filename = v
                }
            end
            def execute
                if options.get_file
                    tic.ticket_get_attachment( options.get_file, options.new_filename )
                else
                    tic.ticket_attach( args[0], options.ticket_id )
                end
            end
        end
    end
end
