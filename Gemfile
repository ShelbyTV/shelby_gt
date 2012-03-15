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

#
# ---------- TODO: explain what yard is and why it's here
#
group :development do
	#gem 'yard', '~> 0.7.4'
	#gem 'yard-rest', '0.3.0', :git => 'git://github.com/rknLA/yard-rest-plugin.git'
end

#
# ---------- Error Monitoring
#
gem 'exception_notification'

#
# ---------- Arnold 2 (aka Link Processor 4)
#
# TODO: check these version (in Gemfile.lock) against those in Shelby if anything is acting odd
group :arnold, :test do
  # Need these in a seperate group b/c em-resolv-replace fucks w/ DNS resolution and will only work inside EventMachine
  # these gems aren't in default group or :production group, so they won't be require'd by default. -> arnold.rb requires them manually.
  # they will, however, be installed via capistrano.  See deploy, it only removes :test, everything else will get installed.
  # Also including these in :test group so we can test the EventMachine code paths (and since test shouldn't resolve DNS, it's no problem)
  gem "eventmachine"
  gem "em-jack"
  gem "em-synchrony"
  gem "em-http-request", :git => "git://github.com/igrigorik/em-http-request.git", :ref => "1a4123d36a298e8043482ad7b20cb18dfbc2616b"
  gem "em-resolv-replace"
end

#
# ---------- Memcached 
#
gem 'memcached', '~>1.4.1'

#gem 'jquery-rails'

# Deploy with Capistrano
gem 'capistrano'

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
	
	# for rspec requests testing (json responses)
	gem 'json_spec' 
	
	# if we have to fuck with time, this looks nice:
	# gem 'timecop'
end