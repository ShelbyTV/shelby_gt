# encoding: UTF-8

require 'spec_helper'
require 'api_clients/facebook_info_getter'

# UNIT test
describe APIClients::FacebookInfoGetter do
  
    before(:each) do
      @user = Factory.create(:user)
      APIClients::FacebookInfoGetter.unstub(:new)
      @info_getter = APIClients::FacebookInfoGetter.new(@user)
    end
    
    it "should return a list of friends ids" do
      @info_getter.stub_chain(:client, :get_connections){
        d = double("friends_collection")
        d.stub(:map).and_return([1,2,3,4])
        d.stub(:next_page).and_return([])
        d
      }
      
      response = @info_getter.get_following_ids
      response.should == [1,2,3,4]
    end

end