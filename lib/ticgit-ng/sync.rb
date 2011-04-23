module TicGitNG
  module Sync
    SYNC_MODULES={}

    #Used to map a source such as the github portion of github:jeffWelling/ticgit
    #to Github_Issues, the module name
    def self.register(mod_name, *sources)
      autoload(mod_name, "ticgit-ng/sync/#{mod_name.downcase}")
      sources.each{|source| SYNC_MODULES[source] = mod_name }
    end

    register 'Github_Issues', 'github', 'gh'

    def self.get command
      if mod_name=SYNC_MODULES[command]
        const_get(mod_name)
      end
    end

    #return value is boolean, true if attr has all of the
    #standard attributes, as defined in standard_attributes()
    def has_standard_attributes attr
      result=standard_attributes.collect {|key,value|
        attr.has_key? key
      }
      !result.include?(false)
    end

    #These are the standard attributes that should be found
    #across all bug trackers, perhaps with various other names
    def standard_attributes
      {:title=>'',
      :body=>'',
      :created_on=>'',
      :state=>'',
      :label=>'',
      :comments=>:optional,
      :comment_created_on=>:depends_on_comments,
      :comment_author=>:depends_on_comments,
      :comment_body=>:depends_on_comments
      }
    end

    #parse the comments in attrs for updates of static fields, denoted
    #by lines in the form of "#KEY=VALUE" where key is an attribute such
    #as state, title, or label.
    def parse_attrs_for_updates attrs, statics
      updates=[]
      comment_regex=/\n#[^=]*="[^"]*"/
      attrs.comments.each {|comment|
        text=comment.comment_body
        while text[comment_regex]
          match=text[comment_regex]
          text.gsub!(match,'')
          updates << match
      }
    end

    #source is in the format of github:jeffWelling/ticgit
    #and get_bugtracker extracts the 'github' portion of it
    def self.get_bugtracker(source)
      source[/^[^:]*/]
    end

    #get repo from source
    def self.get_repo(source)
      source[/[^:]*$/]
    end

    def self.external_sync( source, push )
      bugtracker= get_bugtracker(source)
      repo= get_repo(source)
      
      sync_mod_object= get(bugtracker)

      username='FUBAR'
      token='RABUF'
      if token
        options={:username=>username,:token=>token}
      else
        options={:username=>username,:password=>password}
      end
      
      bugtracker= eval(
        "TicGitNG::Sync::#{sync_mod_object}.new(#{options.inspect})")

      all_bugs= bugtracker.read( repo )

      #sort chronologically
      #merge tickets together


    end
  end
  class GenericBugtracker
    def create
    end

    def read
    end
    
    def update
    end
    
    def destroy
    end
  end

  class SyncableTicket
    def initialize(attributes, static_attributes)
      raise "SyncableTicket.new(attributes): attributes has to be a hash" unless
        attributes.class==Hash

      raise "SyncableTicket.new(attributes): attributes has to at least have the standard attributes: #{standard_attributes.inspect}" unless
        has_standard_attributes(attributes)

      attributes= parse_attrs_for_updates(attributes, static_attributes)

      @attributes=attributes

      #This will allow us to use calls like
      #  ticket=SyncableTicket.new(...)
      #  ticket.title
      #  ticket.body
      #  ...
      attributes.each {|attribute| attr_reader attribute.to_sym }
    end

    def get_attribute attribute=nil
      attribute ? (@attributes[attribute]) : (@attributes)
    end


    def create
    end

    def read
    end
    
    def update
    end
    
    def destroy
    end
  end
end
