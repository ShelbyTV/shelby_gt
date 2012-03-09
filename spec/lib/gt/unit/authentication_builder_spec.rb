# encoding: UTF-8

require 'spec_helper'

require 'user_manager'
require 'authentication_builder'

# UNIT test
describe GT::AuthenticationBuilder do
  before(:each) do
    @u = Factory.create(:user)
    @nickname = "nick-#{rand.to_s}"
    @omniauth_hash = {
      'provider' => "twitter",
      'uid' => '33',
      'credentials' => {
        'token' => "somelongtoken",
        'secret' => 'foreskin',
        'garbage' => 'truck'
      },
      'info' => {
        'name' => 'some name',
        'nickname' => @nickname,
        'image' => "http://original.com/image_normal.png",
        'garbage' => 'truck'
      },
      'garbage' => 'truck'
    }
  end
  
  it "should have_provider from its authentications" do
    @u.authentications << GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    @u.has_provider('twitter').should eq(true)
  end
  
  it "should not have_provider not in its authentications" do
    @u.authentications << GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    @u.has_provider('your mom').should eq(false)
  end
  
  it "should incorporate authentication user image, and larger user image if twitter" do
    auth = GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    @u.authentications << auth
    
    GT::AuthenticationBuilder.normalize_user_info(@u, auth)
    
    @u.user_image.should == "http://original.com/image_normal.png"
    @u.user_image_original.should == "http://original.com/image.png"
  end
  
  it "should incorporate auth user image, and larger user image if twitter, but not if it's a default image" do
    omniauth_hash = {
      'provider' => "twitter",
      'uid' => '33',
      'credentials' => {
        'token' => "somelongtoken",
        'secret' => 'foreskin'
      },
      'info' => {
        'name' => 'some name',
        'nickname' => 'ironically nick',
        'garbage' => 'truck',
        'image' => "http://original.com/default_profile_6_normal.png"
      }
    }

    auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth_hash)
    GT::AuthenticationBuilder.normalize_user_info(@u, auth)
    @u.user_image.should == "http://original.com/default_profile_6_normal.png"
    @u.user_image_original.should == nil
  end
  
  it "should be able to get auth from provider and id" do
    @u.authentications << GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)

    auth = @u.authentication_by_provider_and_uid( "twitter", "33" )
    auth.should_not == nil
    auth.provider.should == "twitter"
    auth.uid.should == "33"
    auth.oauth_token.should == "somelongtoken"
    auth.oauth_secret.should == "foreskin"
  end

  

end