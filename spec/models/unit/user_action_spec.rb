require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe UserAction do
  before(:each) do
    @user_action = UserAction.new
  end
  
  it "should use the database dashboard-entry" do
    @user_action.database.name.should =~ /.*user-action/
  end

  it "should require type" do
    f = UserAction.new
    f.valid?.should == false
    f.errors.messages.include?(:type).should == true
  end
    
end
