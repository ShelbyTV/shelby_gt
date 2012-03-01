require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Roll do
  before(:each) do
    @roll = Roll.new
  end
  
  it "should use the database roll" do
    @roll.database.name.should =~ /.*roll-frame/
  end
  
end
