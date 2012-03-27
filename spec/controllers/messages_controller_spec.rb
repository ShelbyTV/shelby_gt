require 'spec_helper'

describe V1::MessagesController do
  before(:each) do
    @conversation = stub_model(Conversation)
    @message1 = stub_model(Message)
    @message = stub_model(Message)
    Conversation.stub(:find) { @conversation }
    @conversation.stub(:messages) { [@message, @message1] }
    @conversation.stub(:find_message_by_id) { @message }
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
    
    it "returns 400 without message text" do
      post :create, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("text of message required")
    end

    it "returns 401 without a user authenticated" do
      sign_out @user
      post :create, :text => "SOS", :format => :json
      response.should_not be_success
    end
    
    it "returns 404 if it cant find the conversation" do
      Conversation.stub(:find) { nil }
      post :create, :text => "SOS", :format => :json
      assigns(:status).should eq(404)
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
      @conversation.stub(:reload) { [@message1] }
      @conversation.stub(:find_message_by_id) { @message }
      delete :destroy, :conversation_id => @conversation.id, :id => @message.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 404" do
      @conversation.stub(:pull) { true }
      @conversation.stub(:find_message_by_id) { false }
      delete :destroy, :conversation_id => @conversation.id, :id => @message.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
end