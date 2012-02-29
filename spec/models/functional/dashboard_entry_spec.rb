require 'spec_helper'

#Functional: hit the database, treat model as black box
describe DashboardEntry do
  before(:each) do
    @dashboard_entry = DashboardEntry.new
  end
  
  it "should have an index on [user_id, id]" do
    indexes = DashboardEntry.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"a"=>1, "_id"=>-1})
  end
  
  it "should abbreviate user_id as :a" do
    DashboardEntry.keys["user_id"].abbr.should == :a
  end
  
end
