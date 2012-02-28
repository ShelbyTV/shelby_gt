require 'spec_helper'

describe DashboardEntry do
  before(:each) do
    @dashboard_entry = DashboardEntry.new
  end
  
  it "should use the database dashboard-entry" do
    @dashboard_entry.database.name.should =~ /.*dashboard-entry/
  end
  
end
