require 'spec_helper'

describe Video do
  before(:each) do
    @video = Video.new
  end
  
  it "should use the database video" do
    @video.database.name.should =~ /.*video/
  end
  
end
