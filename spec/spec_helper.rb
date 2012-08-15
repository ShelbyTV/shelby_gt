# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require "mongo_mapper_helper"
require 'json'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  
  # to user helpers included with json_spec gem:
  config.include JsonSpec::Helpers
  
  config.before(:each) do
    #never hit Rhombus (stats)
    Rhombus.stub(:post)
    Rhombus.stub(:get)
    #never hits statsD (stats)
    StatsManager::StatsD.stub(:increment)
    StatsManager::StatsD.stub(:decrement)
    StatsManager::StatsD.stub(:timing)
    StatsManager::StatsD.stub(:count)
  end
  
  config.before(:type => :request) do
    GT::UserManager.stub(:start_user_sign_in)
  end
end

# Before running tests, drop all the collections across the DBs and re-create the indexes
MongoMapper::Helper.drop_all_dbs
MongoMapper::Helper.ensure_all_indexes
