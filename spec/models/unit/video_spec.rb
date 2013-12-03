require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Video do
  before(:each) do
    @video = Video.new
  end

  it "should use the database video" do
    @video.database.name.should =~ /.*video/
  end

  it "should have the key liker_count with abbreviation y and default value 0" do
    Video.keys.keys.should include("liker_count")
    Video.keys["liker_count"].abbr.should == :y
    @video.liker_count.should == 0
  end

end
