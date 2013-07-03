source 'https://rubygems.org'

gem 'rails', '3.2.11'

#
# ---------- Database
#
#if/when my key abbreviation gets pulled into the official gem, should move back to that
# key_abbreviation - allowing us to use short keys in mongo but longer attributes in ruby
gem "mongo_mapper", :git => 'git://github.com/spinosa/mongomapper.git', :branch => 'key_abbreviation'
gem "mongo", '>=1.6.4'

#
# ---------- Config
#
gem "settingslogic"

#
# ---------- API
#
gem 'rabl', '~> 0.6.0'
gem 'yajl-ruby', :require => "yajl"
gem "statsd-ruby" # for communicating with graphite server
gem 'rack-cors', :require => 'rack/cors' # for cors preflight requests
gem 'rack-oauth2-server'
#
# ---------- Assets
#
gem "haml"
gem 'jquery-rails'

group :development do
	#
	# -- Quiet Logging
	#
	gem 'quiet_assets'

	#
	# -- Faster development web server
	#
	gem 'thin'

	#
	# -- Preview emails in browser w/o sending
	#
	gem 'mail_view', :git => 'https://github.com/37signals/mail_view.git'
end

#
# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', '~> 3.2.5'
  gem 'compass-rails', '~> 1.0.3'
  gem 'yui-compressor'
end

group :production do
	gem "uglifier"
end

#
# ---------- User Authentication
#
gem 'devise', '>= 2.0'
gem 'mm-devise'

gem 'omniauth', '>= 1.0'
gem 'omniauth-twitter', '~> 0.0.16', :git => 'git://github.com/arunagw/omniauth-twitter.git'
gem 'omniauth-facebook', :git => 'git://github.com/mkdynamic/omniauth-facebook.git'
gem 'omniauth-tumblr', :git => 'git://github.com/jamiew/omniauth-tumblr.git'

gem 'httparty'

#
# ---------- User Avatar
#
gem 'paperclip'
gem 'aws-sdk', '~> 1.3.4'

#
# ---------- External Services
#
gem "youtube_it"  #youtube api
gem "vimeo"       # vimeo api
gem "grackle", '~> 0.3.0' 		# twitter
gem "koala"				# facebook
gem "sendgrid", :git => "git://github.com/PracticallyGreen/sendgrid.git" 	# email, with g.analytics customization
gem "sailthru-client"
gem "awesm", :git => 'git@github.com:ShelbyTV/awesm.git'

gem "sanitize" # for sanitizing html in models
gem "statsd-ruby" # for communicating with graphite server

gem "nokogiri"

gem "km" # for sending events to KissMetrics

gem "pusher" # for remote control

#
# ---------- Performance Monitoring
#

gem 'newrelic_rpm'
gem 'rpm_contrib'

#
# ---------- Scheduled Task Management
#

gem 'whenever', :require => false

#
# ---------- Beanstalk (non-Event Machine, non-Arnold)
#
gem "beanstalk-client", :git => "git://github.com/ShelbyTV/beanstalk-client-ruby.git"

#
# ---------- Email parsing
#
gem 'mail'


#
# ---------- Console I/O for Utils
#
gem 'highline'

#
# ---------- Post events to google analytics
#

gem 'gabba'

#
# ---------- TODO: explain what yard is and why it's here
#
group :development do
	gem 'yard', '~> 0.8.6'
	gem 'redcarpet', '~> 2.3.0'
	#gem 'yard-rest', '0.3.0', :git => 'git://github.com/rknLA/yard-rest-plugin.git'
end

#
# ---------- Error Monitoring
#
gem 'exception_notification', :require => "exception_notifier"

#
# ---------- Arnold 2 (aka Link Processor 4)
#
#
gem "eventmachine"
group :arnold, :test do
	# Need these in a seperate group b/c em-resolv-replace fucks w/ DNS resolution and will only work inside EventMachine
	# these gems aren't in default group or :production group, so they won't be require'd by default. -> arnold.rb requires them manually.
	# they will, however, be installed via capistrano.  See deploy, it only removes :test, everything else will get installed.
	# Also including these in :test group so we can test the EventMachine code paths (and since test shouldn't resolve DNS, it's no problem)
	gem "em-jack"
	gem "em-synchrony"
	gem "em-http-request", :git => "git://github.com/igrigorik/em-http-request.git", :ref => "1a4123d36a298e8043482ad7b20cb18dfbc2616b"
	gem "em-resolv-replace"
end

#
# ---------- Memcached
#
# If install fails, it may be because you're missing some important libs:
# sudo aptitude install libmemcached-dev libsasl2-dev libmemcached-dbg
#
group :arnold, :development, :production do
	#don't want this in tests since it's not required and it's slow as shit
	gem 'memcached', '~>1.4.1'
end

#
# ---------- Formatted Logging
#
gem 'formatted_rails_logger'

# Deploy with Capistrano
gem 'capistrano'
gem 'rvm-capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

#
# ---------- Testing
#
group :test, :development do
	gem 'rspec-rails', '~>2.13'
	gem 'rspec-html-matchers'
end

group :test, :development do
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

#
# ---------- SEO
#
gem "sitemap_generator", "~> 3.2.1"

gem "therubyracer", :require => 'v8'