require 'spec_helper'

#Functional: hit the database, treat model as black box
describe VideoLikerBucket do
  context "database" do
    it "should have an index on [provider_name, provider_id, sequence]" do
      indexes = VideoLikerBucket.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "b"=>1, "c"=>1})
    end
  end
end
