require 'spec_helper'

require 'message_manager'


describe GT::MessageManager do
  
  before(:each) do
    @u = Factory.create(:user, :name => "henry", :user_image => "http://url.here.com/img.png")
    @public = true
    @text = "This is the message text. Deep, I know."
  end
  
  it "should build and return a valid message" do
    options = { :user => @u, :public => true, :text => @text }
    message = GT::MessageManager.build_message(options)
    message.should be_valid
    message.text.should eq(@text)
    message.nickname.should eq(@u.nickname)
    message.public.should eq(@public)
  end
  
  it "should create a message even without text" do
    options = { :user => @u, :public => @public }
    message = GT::MessageManager.build_message(options)    
    message.should be_valid
    message.nickname.should eq(@u.nickname)
    message.public.should eq(@public)
  end
  
  it "should set user_has_shelby_avatar" do
    @u.stub(:has_shelby_avatar).and_return(true)
    options = { :user => @u, :public => @public }
    message = GT::MessageManager.build_message(options)    
    message.should be_valid
    message.user_has_shelby_avatar.should == true
  end
  
  it "should return error if no user, public attr or text is passed" do
    options = { :public => true, :text => @text }
    lambda { GT::MessageManager.build_message(options) }.should raise_error(ArgumentError)
    
    options = { :user => @u, :text => @text }
    lambda { GT::MessageManager.build_message(options) }.should raise_error(ArgumentError)    
  end
  
  it "should not crash with funky input" do
    options = { :public => true, :text => false, :nickname => false, :realname => false, :user_image_url => false }
    GT::MessageManager.build_message(options)
  end
  
end