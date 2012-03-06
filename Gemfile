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
	
	# if we have to fuck with time, this looks nice:
	# gem 'timecop'
end