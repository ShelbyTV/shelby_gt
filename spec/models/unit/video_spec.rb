require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Video do
  before(:each) do
    @video = Video.new
  end
  
  it "should use the database video" do
    @video.database.name.should =~ /.*video/
  end
    
end
