# encoding: UTF-8
require 'spec_helper'

require 'imposter_omniauth'

# UNIT test
describe GT::ImposterOmniauth do
  before(:all) do
    @uid, @token, @secret = "123uid", "token", "secret"
  end
  
  context "choosing correct provider" do    
    it "should detect twitter" do
      GT::ImposterOmniauth.should_receive(:user_info_for_twitter).with(@uid, @token, @secret).exactly(1).times
      GT::ImposterOmniauth.get_user_info("twitter", @uid, @token, @secret)
    end
    
    it "should detect facebook" do
      GT::ImposterOmniauth.should_receive(:user_info_for_facebook).with(@uid, @token).exactly(1).times
      GT::ImposterOmniauth.get_user_info("facebook", @uid, @token)
    end
    
  end
  
  context "twitter" do
    before(:each) do
      @nickname = "nick"
      @name = "real name"
      @location = "NYC 100.107 8098.34"
      @image = "http://image.tv"
      @description = "entropy"
      
      Grackle::Client.stub(:new).and_return(mock_model("GrackleClient", :account => mock_model("GrackleClient2", :verify_credentials? =>
        mock_model("GrackleTwitterStruct", 
          :screen_name => @nickname,
          :name => @name,
          :location => @location,
          :profile_image_url => @image,
          :description => @description))))
    end
    
    it "should return {} if getting user info fails" do
      Grackle::Client.stub(:new).and_return(mock_model("GrackleClient", :account => mock_model("GrackleClient2", :verify_credentials? => nil)))

      omniauth = GT::ImposterOmniauth.get_user_info("twitter", @uid, @token, @secret)
      omniauth.should == {}
    end
    
    it "should set provider and uid" do
      omniauth = GT::ImposterOmniauth.get_user_info("twitter", @uid, @token, @secret)
      
      omniauth['provider'].should == "twitter"
      omniauth['uid'].should == @uid
    end
    
    it "should set credentials" do
      omniauth = GT::ImposterOmniauth.get_user_info("twitter", @uid, @token, @secret)
      
      omniauth['credentials']['token'].should == @token
      omniauth['credentials']['secret'].should == @secret
    end
    
    it "should set info" do
      omniauth = GT::ImposterOmniauth.get_user_info("twitter", @uid, @token, @secret)
      
      omniauth['info']['nickname'].should == @nickname
      omniauth['info']['name'].should == @name
      omniauth['info']['location'].should == @location
      omniauth['info']['image'].should == @image
      omniauth['info']['description'].should == @description
    end
    
  end
  
  context "facebook" do
    before(:each) do
      @nickname = "nick"
      @name = "real name"
      @location = "NYC 100.107 8098.34"
      @image = "http://image.tv"
      @description = "entropy"
      
      @email = "e@mail.com"
      @fist_name = "first"
      @last_name = "last"
      @gender = "male"
      @timezone = "-4"
      
      Koala::Facebook::API.stub(:new).and_return(mock_model("GraphAPI", :get_object =>
        { 'username' => @nickname,
          'name' => @name,
          'location' => {'name' => @location},
          'bio' => @description,
          'email' => @email,
          'first_name' => @first_name,
          'last_name' => @last_name,
          'gender' => @gender,
          'timezone' => @timezone
          }))
    end
    
    it "should return {} if getting user info fails" do
      Koala::Facebook::API.stub(:new).and_return(mock_model("GraphAPI", :get_object => nil))
      
      omniauth = GT::ImposterOmniauth.get_user_info("facebook", @uid, @token, @secret)
      omniauth.should == {}
    end
      
    it "should set provider and uid" do
      omniauth = GT::ImposterOmniauth.get_user_info("facebook", @uid, @token, @secret)
      
      omniauth['provider'].should == "facebook"
      omniauth['uid'].should == @uid
    end
    
    it "should set credentials" do
      omniauth = GT::ImposterOmniauth.get_user_info("facebook", @uid, @token, @secret)
      
      omniauth['credentials']['token'].should == @token
    end
    
    it "should set info" do
      omniauth = GT::ImposterOmniauth.get_user_info("facebook", @uid, @token, @secret)
      
      omniauth['info']['nickname'].should == @nickname
      omniauth['info']['name'].should == @name
      omniauth['info']['location'].should == @location
      omniauth['info']['image'].should == "http://graph.facebook.com/#{@uid}/picture?type=square"
      omniauth['info']['description'].should == @description
      
      omniauth['info']['email'].should == @email
      omniauth['info']['first_name'].should == @first_name
      omniauth['info']['last_name'].should == @last_name
    end
    
    it "should set extra user_hash" do
      omniauth = GT::ImposterOmniauth.get_user_info("facebook", @uid, @token, @secret)
      
      omniauth['extra']['user_hash']['gender'].should == @gender
      omniauth['extra']['user_hash']['timezone'].should == @timezone
    end
      
  end
  
end