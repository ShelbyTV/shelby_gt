require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Frame do
  before(:each) do
    @frame = Frame.new
  end
  
  it "should use the database roll-frame" do
    @frame.database.name.should =~ /.*roll-frame/
  end
  
  it "should update score correctly with each new upvote"
  
  it "should add upvoting user to upvoters array"
  
  it "should not allow user to upvote more than once"
  
end
