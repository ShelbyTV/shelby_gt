# encoding: UTF-8

require 'spec_helper'
require 'api_clients/facebook_info_getter'

# UNIT test
describe APIClients::FacebookInfoGetter do
  
    before(:each) do
      @user = Factory.create(:user)
      @user.authentications << Factory.create(:authentication, :provider => "facebook")
      @user.save
      APIClients::FacebookInfoGetter.unstub(:new)
      @info_getter = APIClients::FacebookInfoGetter.new(@user)
      
      @info_getter.stub_chain(:client, :get_connections){
        d = [{"name" => "Eric Jennings", "id" => "11"}, {"name" => "Dan Herman", "id" => "22"}, {"name" => "Serra Kizar", "id" => "33"}]
        d.stub(:next_page).and_return([])
        d
      }
    end
    
    it "should return a friends ids" do
      response = @info_getter.get_friends_ids
      response.should == ["11", "22", "33"]
    end
    
    it "should return a friends names" do
      response = @info_getter.get_friends_names
      response.should == ["Eric Jennings", "Dan Herman", "Serra Kizar"]
    end
    
    it "should return a dictionary of friends names => id" do
      response = @info_getter.get_friends_names_ids_dictionary
      response.should == {"Eric Jennings"=>"11", "Dan Herman"=>"22", "Serra Kizar"=>"33"}
    end

end