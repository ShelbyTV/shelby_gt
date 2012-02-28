require 'spec_helper'

describe Frame do
  before(:each) do
    @frame = Frame.new
  end
  
  it "should use the database roll-frame" do
    @frame.database.name.should =~ /.*roll-frame/
  end
  
end
