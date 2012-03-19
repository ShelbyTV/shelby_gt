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
  
end
