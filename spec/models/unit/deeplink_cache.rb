require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe DeeplinkCache do
  before(:each) do
    @dl = DeeplinkCache.new
  end
  
  it "should use the database video" do
    @dl.database.name.should =~ /.*deeplink_cache/
  end
    
end
