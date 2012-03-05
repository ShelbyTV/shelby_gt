require 'spec_helper'

describe V1::ConversationController do
  
  describe "GET show" do
    it "assigns one conversation to @conversation" do
      @conversation = stub_model(Conversation)
      Conversation.stub!(:find).and_return(@conversation)
      get :show, :format => :json
      assigns(:conversation).should eq(@conversation)
      assigns(:status).should eq(200)
    end
    
    it "returns 500 when it cant assign one conversation to @conversation" do
      Conversation.stub!(:find).and_return(nil)
      get :show, :format => :json
      assigns(:status).should eq(500)
    end
    
  end
  
end