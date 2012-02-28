require 'spec_helper'

describe Roll do
  before(:each) do
    @roll = Roll.new
  end
  
  it "should use the database roll" do
    @roll.database.name.should =~ /.*roll-frame/
  end
  
end
