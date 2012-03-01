source 'https://rubygems.org'

gem 'rails', '3.2.1'

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
gem 'rabl'
gem 'yard', '~> 0.7.4'
gem 'yard-rest', '0.3.0', :git => 'git://github.com/rknLA/yard-rest-plugin.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'

  gem 'uglifier', '>= 1.0.3'
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