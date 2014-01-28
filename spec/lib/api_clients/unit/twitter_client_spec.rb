# encoding: UTF-8

require 'spec_helper'
require 'api_clients/twitter_client'

# UNIT test
describe APIClients::TwitterClient do

  it "creates a Grackle twitter client with correct token and secret for app and user" do
    c = APIClients::TwitterClient.build_for_token_and_secret('x','y')
    expect(c).to be_an_instance_of(Grackle::Client)
    expect(c.auth[:consumer_key]).to eql Settings::Twitter.consumer_key
    expect(c.auth[:consumer_secret]).to eql Settings::Twitter.consumer_secret
    expect(c.auth[:token]).to eql 'x'
    expect(c.auth[:token_secret]).to eql 'y'
  end

  it "crates a Grackle twitter client with correct token and secret for just our app" do
    c = APIClients::TwitterClient.build_for_app
    expect(c).to be_an_instance_of(Grackle::Client)
    expect(c.auth[:consumer_key]).to eql Settings::Twitter.consumer_key
    expect(c.auth[:consumer_secret]).to eql Settings::Twitter.consumer_secret
    expect(c.auth).not_to have_key :token
    expect(c.auth).not_to have_key :token_secret
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
      }.to_not raise_error

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
      }.to_not raise_error
    end

    it "should raise argument errors when user is missing" do
      expect {
        @client.setup_for_user(nil)
      }.to raise_error(ArgumentError)

      # NOTE: the factory created user has twitter auth, otherwise this would fail
      expect {
        @client.setup_for_user(@user)
      }.to_not raise_error
    end

    it "should raise argument errors when user doesn't have twitter auth" do
      user = User.new
      expect {
        @client.setup_for_user(user)
      }.to raise_error(ArgumentError, 'User must have twitter authentication')
    end

  end

end