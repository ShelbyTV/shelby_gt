require 'spec_helper'

describe Video do
  before(:each) do
    @video = Video.new
  end
  
  it "should have an index on [provider_name, provider_id]" do
    indexes = Video.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"provider_name"=>1, "provider_id"=>1})
  end
  
end
