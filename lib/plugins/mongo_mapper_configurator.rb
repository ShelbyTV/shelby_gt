module Plugins
  module MongoMapperConfigurator
    extend ActiveSupport::Concern
    
    module ClassMethods
      def configure_mongomapper(settings)
        if settings['db_hosts']
          # Starting with a proper Hash and merging into it b/c Mongo::Connection checks if the class is Hash, which it isn't when using Settings
          connection Mongo::MongoReplicaSetClient.new( settings.db_hosts, {}.merge(settings.db_options.merge(Settings::Mongo.db_options)) )
        else
          connection Mongo::MongoClient.new(settings.db_host, settings.db_port, {}.merge(settings.db_options.merge(Settings::Mongo.db_options)) )
        end
        set_database_name settings.db_name
        database.authenticate(settings.db_username, settings.db_password) if settings['db_username'] && settings['db_password']

        plugin MongoMapper::Plugins::IdentityMap if settings.mm_use_identity_map
      end
    end
    
  end
end
