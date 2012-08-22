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
    
    # don't want TwitterInfoGetter trying to make real requests to API
    @twt_info_getter = double("twt_info_getter")
    @twt_info_getter.stub(:get_following_screen_names).and_return(['a','b'])
    @twt_info_getter.stub(:get_following_ids).and_return([0, 1])
    APIClients::TwitterInfoGetter.stub(:new).and_return(@twt_info_getter)
    
    # don't want FacebookInfoGetter trying to make real requests to API
    @fb_info_getter = double("fb_info_getter")
    @fb_info_getter.stub(:get_friends_ids).and_return([0, 1])
    @fb_info_getter.stub(:get_friends_names).and_return(["andy", "beth"])
    @fb_info_getter.stub(:get_friends_names_ids_dictionary).and_return({"dan" => 33, "frank" => 22})
    APIClients::FacebookInfoGetter.stub(:new).and_return(@fb_info_getter)
  end
  
  config.before(:type => :request) do
    GT::UserManager.stub(:start_user_sign_in)
  end
end

# Before running tests, drop all the collections across the DBs and re-create the indexes
MongoMapper::Helper.drop_all_dbs
MongoMapper::Helper.ensure_all_indexes
