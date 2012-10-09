# encoding: UTF-8

require 'spec_helper'
require 'api_clients/sailthru_client'

# UNIT test
describe APIClients::SailthruClient do
  
  context "Argument validation" do

    before(:each) do
      @user = Factory.create(:user)
    end
    
    it "should raise argument errors when required arguments are missing" do
      expect {
        APIClients::SailthruClient.add_user_to_list(nil, "test")
        APIClients::SailthruClient.add_user_to_list(@user, nil)
        APIClients::SailthruClient.send_email(@user, nil)
        APIClients::SailthruClient.send_email(nil, "test")
      }.to raise_error(ArgumentError)
    end
    
  end

end