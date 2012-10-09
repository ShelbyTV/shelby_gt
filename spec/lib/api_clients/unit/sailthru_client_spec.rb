# encoding: UTF-8

require 'spec_helper'
require 'api_clients/sailthru_client'

# UNIT test
describe APIClients::SailthruClient do
  
  context "Argument validation" do

    before(:each) do
      @client = APIClients::SailthruClient.new
      @user = Factory.create(:user)
    end
    
    it "should raise argument errors when user is mising" do
      expect {
        APIClients::SailthruClient.add_user_to_list(nil)
      }.to raise_error(ArgumentError)
    end
    
  end

end