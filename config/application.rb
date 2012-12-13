require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "sprockets/railtie"
require "rails/test_unit/railtie"

# an oauth server
require 'rack/oauth2/server'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module ShelbyGt
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{Rails.root}/lib/plugins #{Rails.root}/lib/db #{Rails.root}/lib/gt #{Rails.root}/lib/gt/arnold #{Rails.root}/lib/gt/user #{Rails.root}/lib/cache #{Rails.root}/lib/embedly #{Rails.root}/lib/utils #{Rails.root}/lib/stats #{Rails.root}/lib/social_postings)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    # config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'
    
    #default to mongomapper as orm
    config.generators do |g|
      g.orm :mongo_mapper
    end
    
    # Setup cors preflight request headers
    # N.B. Although configed for only put/post/delete, Access-Control-Allow-Origin will be set to the requests origin if it matches here
    #      and the request is with credentials (even if it's not a pre-flight).  As such, the '*' set in application_controller is fine
    #      b/c it always gets overridden for credentialed requests
    config.middleware.use Rack::Cors do
      allow do
        origins 'web.gt.shelby.tv', 'gt.shelby.tv', 'isoroll.shelby.tv', 'https://shelby.tv', 'shelby.tv', 'https://fb.shelby.tv','fb.shelby.tv', 'm.shelby.tv', 'staging.shelby.tv', 'localhost.shelby.tv:3000', '192.168.2.18:3000', '192.168.2.190:3000', 'm.localhost.shelby.tv:3000'
        resource %r{/v1/(beta_invite|conversation|dashboard|discussion_roll|frame|gt_interest|roll|twitter|user|video|remote_control)\w*},
          :headers => ['Origin', 'Accept', 'Content-Type', 'X-CSRF-Token', 'X-Shelby-User-Agent'],
          :methods => [:put, :post, :delete]
      end
      
    end

    # Config stuff that relieson Settings object can go in here
    config.after_initialize do
      
      # OAuth Server
      settings = Settings::OauthServer
      
      if settings['db_hosts']
        # Starting with a proper Hash and merging into it b/c Mongo::Connection checks if the class is Hash, which it isn't when using Settings
        conn = Mongo::ReplSetConnection.new( settings.db_hosts, {}.merge(settings.db_options.merge(Settings::Mongo.db_options)) )
      else
        conn = Mongo::Connection.new(settings.db_host, settings.db_port, {}.merge(settings.db_options.merge(Settings::Mongo.db_options)) )
      end
      config.oauth.database = conn.db(settings.db_name)
      
      # Mailer
      Rails.application.routes.default_url_options[:host] = Settings::Global.api_host
    end
  end
end
