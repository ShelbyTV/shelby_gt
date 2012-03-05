require 'spec_helper'

describe V1::MessagesController do
  before(:each) do
    @conversation = stub_model(Conversation)
    @message1 = stub_model(Message)
    @message = stub_model(Message)
    Conversation.stub(:find) { @conversation }
    @conversation.stub(:messages) { [@message, @message1] }
  end  

  describe "POST create" do
    it "creates and assigns one frame to @frame" do
      post :create, :format => :json
      assigns(:message).should eq(@message)
    end
  end
  
  describe "DELETE destroy" do
    it "destroys a message successfuly" do
      @conversation.stub(:pull) { [@message1] }
      @conversation.stub(:reload) { @conversation }
      delete :destroy, :conversation_id => @conversation.id, :id => @message.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 500" do
      @conversation.stub(:pull) { false }
      delete :destroy, :conversation_id => @conversation.id, :id => @message.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
end