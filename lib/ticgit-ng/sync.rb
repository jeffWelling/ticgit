module TicGitNG
  module Sync
    def has_standard_attributes
    end

    def standard_attributes
      
    end

    def parse_attrs_for_updates
    end

    def self.external_sync( source, push )
      bugtracker= get_bugtracker(source)
      repo= get_repo(source)
      

      #read bug tracker
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
    def initialize(attributes)
      raise "SyncableTicket.new(attributes): attributes has to be a hash" unless
        attributes.class==Hash

      raise "SyncableTicket.new(attributes): attributes has to at least have the standard attributes: #{standard_attributes.inspect}" unless
        has_standard_attributes(attributes)

      attributes= parse_attrs_for_updates(attributes)

      @attributes=attributes
    end

    def get_attribute( attr )
      @attributes[attr]
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
