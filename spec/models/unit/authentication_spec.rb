require 'spec_helper'

describe Authentication do

  it "should validate w/ omniauth and twitter" do
    auth = Authentication.build_from_omniauth(@valid_twitter_omniauth_hash)
    
    auth.valid?.should eql(true)
  end
  
  it "should validate w/ omniauth and facebook" do
    omniauth_hash = {
      'provider' => "facebook",
      'uid' => '33',
      'credentials' => {
        'token' => "somelongtoken",
        'secret' => 'foreskin',
        'garbage' => 'truck'
      },
      'user_info' => {
        'name' => 'some name',
        'nickname' => 'ironically nick',
        'garbage' => 'truck'
      },
      'garbage' => 'truck'
    }

    auth = Authentication.build_from_omniauth(omniauth_hash)
    
    auth.valid?.should eql(true)
  end
  
  it "should validate w/ omniauth and tumblr" do
    omniauth_hash = {
      'provider' => "tumblr",
      'uid' => 'shelbytv',
      'credentials' => {
        'token' => "somelongtoken",
        'secret' => 'foreskin',
        'garbage' => 'truck'
      },
      'user_info' => {
        'name' => 'some name',
        'nickname' => 'ironically nick',
        'garbage' => 'truck'
      },
      'garbage' => 'truck'
    }

    auth = Authentication.build_from_omniauth(omniauth_hash)
    
    auth.valid?.should eql(true)
  end
 
  it "should not validate without a valid provider" do
      omniauth_hash = {
        'provider' => "mothafucka",
        'uid' => '33',
        'credentials' => {
          'token' => "somelongtoken",
          'secret' => 'foreskin',
          'garbage' => 'truck'
        },
        'user_info' => {
          'name' => 'some name',
          'nickname' => 'ironically nick',
          'garbage' => 'truck'
        },
        'garbage' => 'truck'
      }

      auth = Authentication.build_from_omniauth(omniauth_hash)

      auth.valid?.should eql(false)
  end  
    
  it "should be raise arg errors w/o full omniauth shit" do
    lambda { Authentication.build_from_omniauth({}) }.should raise_error(ArgumentError)
  end
  
  it "should initialize video processing when part of initial user creation" do
    #create new (unsvaed) user w/ 1 auth, make sure that auth runs initialize_video_processing
    user = Factory.build(:user)
    auth = Authentication.build_from_omniauth(@valid_twitter_omniauth_hash)
    auth.new?.should == true
    # hacky way to test that initialize_video_processing is called:
    expect { auth.initialize_video_processing }.to_not change{auth}.to(user)
    
    user.authentications << auth
    user.save.should == true
    auth.new?.should == false
  end
  
  it "should initialize video processing when added to an already created user" do
    #create and save a user, add auth, make sure that auth runs initialize_video_processing
    user = Factory.create(:user)
    
    #ONCE
    auth = Authentication.build_from_omniauth(@valid_twitter_omniauth_hash)
    # hacky way to test that initialize_video_processing is called:
    expect { auth.initialize_video_processing }.to_not change{auth}.to(user)
    
    user.authentications << auth
    user.save.should == true
    
    #TWICE
    auth2 = Authentication.build_from_omniauth(@valid_twitter_omniauth_hash)
    # hacky way to test that initialize_video_processing is called:
    expect { auth2.initialize_video_processing }.to_not change{auth}.to(user)
    
    user.authentications << auth2
    user.save.should == true
    user.authentications.size.should == 2
  end
  
  it "should only initialize video processing once" do
    #create and save user, add auth, save user, save user again; make sure auth runs initialize_video_processing *only once*
    user = Factory.create(:user)
    
    auth = Authentication.build_from_omniauth(@valid_twitter_omniauth_hash)
    # hacky way to test that initialize_video_processing is called:
    expect { auth.initialize_video_processing }.to_not change{auth}.to(user)

    
    user.authentications << auth
    user.save.should == true
    user.save.should == true
    user.valid?.should == true
    user.save.should == true
    user.save.should == true
  end
  
  it "should validate when via facebook app" do
    facebook_hash = {
      'provider' => "facebook",
      'id' => '33',
      'name' => 'some name',
      'username' => 'ironically nick',
      'email' => "nick@name.com"
    }
    
    token = "somelongtoken"
    
    permissions = {:offline => 1, :you_mom => 1, :visitation_rights => 0}

    auth = Authentication.build_from_facebook(facebook_hash, token, permissions)
    
    auth.valid?.should eql(true)
  end
  
  before(:each) do
    @valid_twitter_omniauth_hash = {
      'provider' => "twitter",
      'uid' => '33',
      'credentials' => {
        'token' => "somelongtoken",
        'secret' => 'foreskin',
        'garbage' => 'truck'
      },
      'user_info' => {
        'name' => 'some name',
        'nickname' => 'ironically nick',
        'garbage' => 'truck'
      },
      'garbage' => 'truck'
    }
  end
end