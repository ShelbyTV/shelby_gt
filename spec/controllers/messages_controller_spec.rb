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
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
    end
    
    it "creates and assigns one message to @new_message" do
      Message.stub!(:new).and_return(@message)
      @conversation.stub(:valid?).and_return(true)
      post :create, :text => "SOS", :format => :json
      assigns(:new_message).should eq(@message)
      assigns(:status).should eq(200)
    end
    
    it "returns 500 without message text" do
      post :create, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("text of message required")
    end

    it "returns 500 without a user authenticated" do
      sign_out @user
      post :create, :text => "SOS", :format => :json
      response.should_not be_success
    end
    
    it "returns 500 if it cant find the conversation" do
      Conversation.stub(:find) { nil }
      post :create, :text => "SOS", :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not find that conversation")
    end
    
  end
  
  describe "DELETE destroy" do
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
    end
    
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