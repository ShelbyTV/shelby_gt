require 'spec_helper'

describe DashboardEntry do
  before(:each) do
    @dashboard_entry = DashboardEntry.new
  end
  
  it "should have an index on [user_id, created_at]" do
    indexes = DashboardEntry.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"user_id"=>1, "created_at"=>-1})
  end
  
end
