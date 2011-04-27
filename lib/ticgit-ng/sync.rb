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
    def self.has_standard_attributes attrs
      require 'pp'
      pp attrs
      TicGitNG::Sync.standard_attributes.each {|attribute, value|
        if attribute==:comments
          if (attrs.has_key?(attribute) or attrs.has_key?(attribute.to_s))
            attribute=attribute.to_s unless attrs.has_key?(attribute)
            attrs[attribute].each {|comment|
              value.each_key {|comment_value|
                return false unless (comment.has_key?(comment_value) or comment.has_key?(comment_value.to_s))
              }
            }
          end
        else
          return false unless (attrs.has_key?(attribute) or attrs.has_key?(attribute.to_s))
        end
        
      }

    end

    #These are the standard attributes that should be found
    #across all bug trackers, perhaps with various other names
    def self.standard_attributes
      {:title=>'',
      :body=>'',
      :created_on=>'',
      :state=>'',
      :label=>'',
      :comments=>{
        :comment_created_on=>:depends_on_comments,
        :comment_author=>:depends_on_comments,
        :comment_body=>:depends_on_comments
        }
      }
    end

    #parse the comments in attrs for updates of static fields, denoted
    #by lines in the form of "#KEY=VALUE" where key is an attribute such
    #as state, title, or label.
    def self.parse_attrs_for_updates attrs, statics
      updates=[]
      comment_regex=/\n#[^=]*="[^"]*"/
      comment_key='comments'
      comment_key=comment_key.to_sym unless attrs.has_key?(comment_key)
      attrs[comment_key].each {|comment|
        c_b_key='comment_body'
        c_b_key=c_b_key.to_sym unless comment.has_key?(c_b_key)
        text=comment[c_b_key]
        while text[comment_regex]
          match=text[comment_regex]
          text.gsub!(match,'')
          updates << match
        end
      }
      updates.each {|update|
        attr_key,attr_value = update.strip.gsub(/#/,'')
        attr_key=attr_key.downcase
        next if statics.include?(attr_key) 
        attrs.set(attr_key, attr_value)
      }
      attrs
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

    def self.external_sync( source, push=true )
      bugtracker= get_bugtracker(source)
      repo= get_repo(source)
      
      sync_mod_object= get(bugtracker)
      auth_info= get_auth_info
      s="#{sync_mod_object}.new(#{auth_info.inspect})"
      bugtracker= eval(s)
      all_bugs= bugtracker.read( repo )
      #sort chronologically
      #merge tickets together


    end
    def self.get_auth_info
      auth_info={}
      auth_info.merge!( {:username=> `git config github.user`.strip} )
      auth_info.merge!( {:token=> `git config github.token`.strip} )
      auth_info
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
      
      raise "\n\nSyncableTicket.new(attributes): attributes has to at least have the standard attributes: \n#{TicGitNG::Sync.standard_attributes.inspect}\n" unless
        TicGitNG::Sync.has_standard_attributes(attributes)

      attributes= TicGitNG::Sync.parse_attrs_for_updates(attributes, static_attributes)

      #FIXME Convert all attribute keys to symbols before storing
      #For convenience, we allow attribute keys to be strings or symbols
      #but we need to convert them to symbols to standardize the SyncableTicket
      #attributes


      @attributes=attributes

      #This will allow us to use calls like
      #  ticket=SyncableTicket.new(...)
      #  ticket.title
      #  ticket.body
      #  ...
      (class << self ; self ; end).class_eval {
        attributes.each_key {|attribute|
          attr_accessor attribute.to_sym
        }
      }
    end

    def get_attribute attribute=nil
      attribute ? (@attributes[attribute]) : (@attributes)
    end

    def set key, value
      @attributes[key]=value
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
