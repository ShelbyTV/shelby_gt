# encoding: UTF-8

require 'spec_helper'
require 'api_clients/twitter_info_getter'

# UNIT test
describe APIClients::TwitterInfoGetter do
  
    before(:each) do
      @user = Factory.create(:user)
      @info_getter = APIClients::TwitterInfoGetter.new(@user)
    end
    
    it "should return a list of screen names" do
      @info_getter.stub_chain(:twitter_client, :friends, :ids?) {(1..4998)}
      @info_getter.stub_chain(:twitter_client, :users, :lookup?).and_return { |arg|
         arg[:user_ids].map {|i| 
          struct = OpenStruct.new
          struct.screen_name = 'screen_name_for_' + i.to_s
          struct
        }
      }

      response = @info_getter.get_following_screen_names
      response.should == (1..4998).map {|i| 'screen_name_for_' + i.to_s}
    end

end