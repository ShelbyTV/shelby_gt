# encoding: UTF-8

require 'spec_helper'
require 'api_clients/twitter_client'

# UNIT test
describe APIClients::TwitterClient do
  
  it "should create a Grackle twitter client given appropriate parameters" do
    c = APIClients::TwitterClient.build_for_token_and_secret('x','y')
    c.should be_an_instance_of(Grackle::Client)
  end

  context "Argument validation" do

    before(:each) do
      @client = APIClients::TwitterClient.new
      @user = Factory.create(:user)
    end
    
    it "should raise argument errors when oauth_token or oauth_secret are mising" do
      expect {
        APIClients::TwitterClient.build_for_token_and_secret(nil, nil)
      }.to raise_error(ArgumentError)

      expect {
        APIClients::TwitterClient.build_for_token_and_secret('x', nil)
      }.to raise_error(ArgumentError)

      expect {
        APIClients::TwitterClient.build_for_token_and_secret(nil, 'y')
      }.to raise_error(ArgumentError)

      expect {
        APIClients::TwitterClient.build_for_token_and_secret('x', 'y')
      }.to_not raise_error(ArgumentError)

      expect {
        @client.setup_for_token_and_secret(nil, nil)
      }.to raise_error(ArgumentError)

      expect {
        @client.setup_for_token_and_secret('x', nil)
      }.to raise_error(ArgumentError)

      expect {
        @client.setup_for_token_and_secret(nil, 'y')
      }.to raise_error(ArgumentError)

      expect {
        @client.setup_for_token_and_secret('x', 'y')
      }.to_not raise_error(ArgumentError)
    end
    
    it "should raise argument errors when user is missing" do
      expect {
        @client.setup_for_user(nil)
      }.to raise_error(ArgumentError)

      # NOTE: the factory created user has twitter auth, otherwise this would fail
      expect {
        @client.setup_for_user(@user)
      }.to_not raise_error(ArgumentError)
    end

    it "should raise argument errors when user doesn't have twitter auth" do
      user = User.new
      expect {
        @client.setup_for_user(user)
      }.to raise_error(ArgumentError, 'User must have twitter authentication')
    end

  end

end