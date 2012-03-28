require 'spec_helper'

require 'message_manager'


describe GT::MessageManager do
  
  before(:each) do
    @u = Factory.create(:user, :name => "henry", :user_image => "http://url.here.com/img.png")
    @public = true
    @text = "This is the message text. Deep, I know."
  end
  
  it "should build and return a valid message" do
    options = { :creator => @u, :public => true, :text => @text }
    message = GT::MessageManager.create_message(options)
    message.should be_valid
    message.text.should eq(@text)
    message.nickname.should eq(@u.nickname)
    message.public.should eq(@public)
  end
  
  it "should return error if no user, public attr or text is passed" do
    options = { :public => true, :text => @text }
    lambda { GT::MessageManager.create_message(options) }.should raise_error(ArgumentError)
    
    options = { :creator => @u, :text => @text }
    lambda { GT::MessageManager.create_message(options) }.should raise_error(ArgumentError)    
  end
  
  it "should return a nil message if no text" do
    options = { :creator => @u, :public => @public }
    message = GT::MessageManager.create_message(options)    
    message.should eq(nil)
  end
  
end