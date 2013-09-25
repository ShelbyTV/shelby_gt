# encoding: UTF-8

require 'spec_helper'

require 'facebook_friend_ranker'

# UNIT test
describe APIClients::FacebookFriendRanker do

  context "get_friends_sorted_by_rank" do
    before(:each) do
      @user = Factory.create(:user)
      @user.authentications << Factory.create(:authentication, :provider => "facebook")
      @user.save
    end

    it "should throw exception w/o a user" do
      Koala::Facebook::API.stub_chain(:new, :get_connections).and_return :whatever
      lambda {
        APIClients::FacebookFriendRanker.new(nil)
      }.should raise_error(ArgumentError)
    end

    it "should throw exception w a user but no auth" do
      @user.authentications = []
      lambda {
        APIClients::FacebookFriendRanker.new(@user)
      }.should raise_error(ArgumentError)
    end

  end

end
