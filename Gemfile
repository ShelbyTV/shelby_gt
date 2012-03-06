source 'https://rubygems.org'

gem 'rails', '3.2.2'

#
# ---------- Database
#
#if/when my key abbreviation gets pulled into the official gem, should move back to that
gem "mongo_mapper", :git => 'git://github.com/spinosa/mongomapper.git', :branch => 'key_abbreviation'
gem "bson_ext"

#
# ---------- Config
#
gem "settingslogic"

#
# ---------- API
#
gem 'rabl','~> 0.6.0'
gem 'yajl-ruby', :require => "yajl"

#
# ---------- Assets
#
gem "haml"
gem "compass", "0.11.7"
#gem "jammit"

#
# ---------- User Authentication
#
gem 'devise', '>= 2.0'
gem 'mm-devise'

gem 'omniauth', '~> 1.0.2'
gem 'omniauth-twitter', :git => 'git://github.com/arunagw/omniauth-twitter.git'
gem 'omniauth-facebook', :git => 'git://github.com/mkdynamic/omniauth-facebook.git'
gem 'omniauth-tumblr', :git => 'git://github.com/jamiew/omniauth-tumblr.git'

gem 'httparty'

#
# ---------- External Services
#
gem "grackle" 		# twitter
gem "koala"				# facebook
gem "sendgrid" 		# email
gem "sailthru-client"

gem "sanitize" # for sanitizing html in models
gem "statsd-ruby" # for communicating with graphite server


#
# ---------- Beanstalk (non-Event Machine, non-Arnold)
#
gem "beanstalk-client", :git => "git://github.com/ShelbyTV/beanstalk-client-ruby.git"

#
# ---------- Async Processing
#
gem 'delayed_job', :git => 'git://github.com/collectiveidea/delayed_job.git'
gem 'delayed_job_mongo_mapper', :git => 'git://github.com/ShelbyTV/delayed_job_mongo_mapper.git'


group :development do
	gem 'yard', '~> 0.7.4'
	gem 'yard-rest', '0.3.0', :git => 'git://github.com/rknLA/yard-rest-plugin.git'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'

  gem 'uglifier', '>= 1.0.3'
end


#
# ---------- External Services
#
# gem "grackle" 		# twitter


#gem 'jquery-rails'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

#
# ---------- Testing
#
group :test, :development do
	gem 'rspec-rails'
	
end

group :test do
	gem 'shoulda'
	
	# rspec has nice mocking, but we could also use
	# gem 'mocha'
	# and then change the config in spec/spec_helper.rb
	
	gem 'factory_girl_rails'
	
	# if we have to fuck with time, this looks nice:
	# gem 'timecop'
end