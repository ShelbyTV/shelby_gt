# encoding: UTF-8

require 'spec_helper'
require 'api_clients/twitter_info_getter'

# UNIT test
describe APIClients::TwitterInfoGetter do

    before(:each) do
      @user = Factory.create(:user)
      APIClients::TwitterInfoGetter.unstub(:new)
      @info_getter = APIClients::TwitterInfoGetter.new(@user)
    end

    it "should return a list of friends ids" do
      @info_getter.stub_chain(:twitter_client, :friends, :ids?).and_return(OpenStruct.new(:ids => (1..4998).to_a))

      response = @info_getter.get_following_ids
      response.should == (1..4998).map {|i| i}
    end

    it "should return a list of screen names" do
      @info_getter.stub_chain(:twitter_client, :friends, :ids?).and_return(OpenStruct.new(:ids => (1..4998).to_a))
      @info_getter.stub_chain(:twitter_client, :users, :lookup?).and_return { |arg|
         arg[:user_id].split(",").map {|i|
          OpenStruct.new(:screen_name => 'screen_name_for_' + i.to_s)
        }
      }

      response = @info_getter.get_following_screen_names
      response.should == (1..4998).map {|i| 'screen_name_for_' + i.to_s}
    end

    it "returns a user's info" do
      twitter_user_id = @user.authentications.first.uid
      user_route = double("user_route")
      user_route.should_receive(:show?).with(:user_id => twitter_user_id, :include_entities => false).and_return { |arg|
        OpenStruct.new(:id => arg[:user_id])
      }
      @info_getter.stub_chain(:twitter_client, :users).and_return(user_route)

      response = @info_getter.get_user_info
      response.id.should == twitter_user_id
    end

end