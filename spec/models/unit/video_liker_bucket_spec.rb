require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe VideoLikerBucket do
  before(:each) do
    @vlb = VideoLikerBucket.new
  end

  it "uses the database video-liker" do
    @vlb.database.name.should =~ /.*video-liker/
  end

  it "has the correct keys, abbreviations, and default values" do
    VideoLikerBucket.keys.keys.should include("provider_name")
    VideoLikerBucket.keys["provider_name"].abbr.should == :a

    VideoLikerBucket.keys.keys.should include("provider_id")
    VideoLikerBucket.keys["provider_id"].abbr.should == :b

    VideoLikerBucket.keys.keys.should include("sequence")
    VideoLikerBucket.keys["sequence"].abbr.should == :c
    @vlb.sequence.should == 0
  end

end
