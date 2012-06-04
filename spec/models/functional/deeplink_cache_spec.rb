require 'spec_helper'

#Functional: hit the database, treat model as black box
describe DeeplinkCache do
  before(:each) do
    @video = DeeplinkCache.new
  end
  
  context "database" do
    
    it "should have an index on [provider_name, provider_id]" do
      indexes =DeeplinkCache.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
    end
  
    it "should abbreviate a as :provider_name, b as :provider_id" do
      DeeplinkCache.keys["url"].abbr.should == :a
    end
  
  end
  
  context "validations" do
    before(:each) do
      @dl = DeeplinkCache.new
      @dl.url = "validates"
      
    end
    #don't need validates since done by index   
    #it "should validate uniqueness of provider_name and provider_id" do
    #  dl = DeeplinkCache.new
    #  dl.url = @dl.url
    #  dl.valid?.should == false
    #  dl.save.should == false
    #  dl.errors.messages.include?(:provider_id).should == true
    #end

    #it "should throw error when trying to create a video where index (ie provider_name + provider_id) already exists"  do
     # lambda {
     #   dl = DeeplinkCache.new
     #   dl.url = "yt"
     #   dl.save
     # }.should change {DeeplinkCache.count} .by 1
     # lambda {
     #   dl = DeeplinkCache.new
     #   dl.url = "yt"
     #   dl.save(:validate => false)
     # }.should raise_error Mongo::OperationFailure
    #end
    
  end
  
end
