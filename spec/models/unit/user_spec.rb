# encoding: utf-8
require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe User do
  before(:each) do
    @user = User.new
  end

  it "should use the database user" do
    @user.database.name.should =~ /.*user/
  end

  it "should be able to hold 1000 roll followings" do
    1000.times do
      @user.roll_followings << Factory.create(:roll_following)
    end
    @user.save #should not raise an error
  end

  it "should have key website with abbreviation bc" do
    User.keys.keys.should include("website")
    User.keys["website"].abbr.should == :bc
  end

  it "should have key dot_tv_description with abbreviation bd" do
    User.keys.keys.should include("dot_tv_description")
    User.keys["dot_tv_description"].abbr.should == :bd
  end

  it "should have the key rolled_since_last_notification with abbreviation bf" do
    User.keys.keys.should include("rolled_since_last_notification")
    User.keys["rolled_since_last_notification"].abbr.should == :bf
    @user.rolled_since_last_notification.should == {"email" => 0}
  end

  it "has the key apn_tokens with abbreviation bh" do
    User.keys.keys.should include("apn_tokens")
    User.keys["apn_tokens"].abbr.should == :bh
    expect(@user.apn_tokens).to be_empty
  end

end
