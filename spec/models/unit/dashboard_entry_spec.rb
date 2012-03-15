require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe DashboardEntry do
  before(:each) do
    @dashboard_entry = DashboardEntry.new
  end
  
  it "should use the database dashboard-entry" do
    @dashboard_entry.database.name.should =~ /.*dashboard-entry/
  end
    
end
