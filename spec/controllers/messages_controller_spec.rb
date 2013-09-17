require 'spec_helper'

describe V1::MessagesController do
  before(:each) do
    @comment = "how much would a wood chuck chuck..."
    @message1 = Factory.create(:message, :text => @comment, :user => Factory.create(:user))
    @message = Factory.create(:message, :text => @comment, :user => Factory.create(:user))
    @conversation = Factory.create(:conversation, :messages => [@message1, @message])

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
      Message.stub(:new).and_return(@message)
      @conversation.stub(:valid?).and_return(true)
      post :create, :conversation_id => @conversation.id.to_s, :text => "SOS", :format => :json
      assigns(:status).should eq(200)
      assigns(:new_message).should eq(@message)
    end

    it "returns 401 without a user authenticated" do
      sign_out @user
      post :create, :conversation_id => @conversation.id.to_s, :text => "SOS", :format => :json
      response.should_not be_success
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