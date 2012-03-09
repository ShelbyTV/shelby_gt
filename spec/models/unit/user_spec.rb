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
  
end
