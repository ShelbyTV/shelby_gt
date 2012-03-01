require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Conversation do
  before(:each) do
    @conversation = Conversation.new
  end
  
  it "should use the database conversation" do
    @conversation.database.name.should =~ /.*conversation/
  end
  
end
