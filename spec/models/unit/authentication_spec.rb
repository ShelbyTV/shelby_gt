# encoding: UTF-8

require 'spec_helper'

require 'user_manager'


describe Authentication do

  it "should validate w/ omniauth and twitter" do
    auth = GT::UserManager.send(:build_authentication_from_omniauth, @valid_twitter_omniauth_hash)
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

    auth = GT::UserManager.send(:build_authentication_from_omniauth, omniauth_hash)
    
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

    auth = GT::UserManager.send(:build_authentication_from_omniauth, omniauth_hash)
    
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

    auth = GT::UserManager.send(:build_authentication_from_omniauth, omniauth_hash)

      auth.valid?.should eql(false)
  end  
    
  it "should be raise arg errors w/o full omniauth shit" do
    lambda { GT::UserManager.send(:build_authentication_from_omniauth, {}) }.should raise_error(ArgumentError)
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

    auth = GT::UserManager.send(:build_authentication_from_facebook, facebook_hash, token, permissions)
    
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