require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Video do
  before(:each) do
    @video = Video.new
  end
  
  it "should have an index on [provider_name, provider_id]" do
    indexes = Video.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"a"=>1, "b"=>1})
  end
  
  it "should abbreviate a as :provider_name, b as :provider_id" do
    Video.keys["provider_name"].abbr.should == :a
    Video.keys["provider_id"].abbr.should == :b
  end
  
end
