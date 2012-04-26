module Plugins
  module MongoMapperConfigurator
    extend ActiveSupport::Concern
    
    module ClassMethods
      def configure_mongomapper(settings)
        if settings['db_hosts']
          connection Mongo::ReplSetConnection.new( settings.db_hosts, settings.db_options.merge(Settings::Mongo.db_options) )
        else
          connection Mongo::Connection.new(settings.db_host, settings.db_port, settings.db_options.merge(Settings::Mongo.db_options) )
        end
        set_database_name settings.db_name
        database.authenticate(settings.db_username, settings.db_password) if settings['db_username'] && settings['db_password']
      end
    end
    
  end
end