require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Frame do
  before(:each) do
    @frame = Frame.new
  end
  
  it "should use the database roll-frame" do
    @frame.database.name.should =~ /.*roll-frame/
  end
  
end
