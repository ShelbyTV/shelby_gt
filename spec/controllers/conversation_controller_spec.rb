require 'spec_helper'

describe V1::ConversationController do
  
  describe "GET show" do
    before(:each) do
      @u = Factory.create(:user)
      sign_in @u
    end
    
    it "assigns one conversation to @conversation" do
      @conversation = Factory.create(:conversation)
      Conversation.stub!(:find).and_return(@conversation)
      get :show, :id => @conversation.id.to_s, :format => :json
      assigns(:conversation).should eq(@conversation)
      assigns(:status).should eq(200)
    end
    
    it "returns 400 when it cant assign one conversation to @conversation" do
      Conversation.stub!(:find).and_return(nil)
      get :show, :id => "whatever", :format => :json
      assigns(:status).should eq(404)
    end
    
  end
  
end