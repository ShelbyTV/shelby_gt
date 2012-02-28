require 'spec_helper'

describe User do
  before(:each) do
    @user = User.new
  end
  
  it "should use the database user" do
    @user.database.name.should =~ /.*user/
  end
  
end
