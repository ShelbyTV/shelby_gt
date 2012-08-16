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
      @info_getter.stub_chain(:twitter_client, :friends, :ids?) {
        struct = OpenStruct.new
        struct.ids = (1..4998).to_a
        struct
      }
      
      response = @info_getter.get_following_ids
      response.should == (1..4998).map {|i| i}
    end
    
    it "should return a list of screen names" do
      @info_getter.stub_chain(:twitter_client, :friends, :ids?) {
        struct = OpenStruct.new
        struct.ids = (1..4998).to_a
        struct
      }
      @info_getter.stub_chain(:twitter_client, :users, :lookup?).and_return { |arg|
         arg[:user_id].split(",").map {|i|
          struct = OpenStruct.new
          struct.screen_name = 'screen_name_for_' + i.to_s
          struct
        }
      }

      response = @info_getter.get_following_screen_names
      response.should == (1..4998).map {|i| 'screen_name_for_' + i.to_s}
    end

end