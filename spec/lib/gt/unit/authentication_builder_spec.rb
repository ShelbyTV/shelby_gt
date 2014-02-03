# encoding: UTF-8

require 'spec_helper'

require 'user_manager'
require 'authentication_builder'

# UNIT test
describe GT::AuthenticationBuilder do
  before(:each) do
    @u = Factory.create(:user)
    @u.primary_email = nil
    @u.user_image = nil
    @u.user_image_original = nil
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
        'email' => "test@test.com",
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

  context "user_image(_original)" do

    before(:each) do
      @auth = GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    end

    it "incorporates authentication auth.image as user_image and larger user_image_original if twitter" do
      GT::AuthenticationBuilder.normalize_user_info(@u, @auth)

      expect(@u.user_image).to eql "http://original.com/image_normal.png"
      expect(@u.user_image_original).to eql "http://original.com/image.png"
    end

    it "does not incorporate auth.image as user_image if the user already has a user_image" do
      @u.user_image = 'someimage.png'
      expect {
        GT::AuthenticationBuilder.normalize_user_info(@u, @auth)
      }.not_to change(@u, :user_image)
    end

    it "does not incorporate auth.image as user_image_original if the user already has a user_image" do
      @u.user_image = 'someimage.png'
      expect {
        GT::AuthenticationBuilder.normalize_user_info(@u, @auth)
      }.not_to change(@u, :user_image_original)
    end

    it "makes user_image and user_image_original the same if not twitter" do
      @auth.provider = 'facebook'
      GT::AuthenticationBuilder.normalize_user_info(@u, @auth)

      expect(@u.user_image).to eql "http://original.com/image_normal.png"
      expect(@u.user_image_original).to eql "http://original.com/image_normal.png"
    end

    it "always updates user_image_original when it updates user_image" do
      @u.user_image_original = 'someimage.png'
      GT::AuthenticationBuilder.normalize_user_info(@u, @auth)

      expect(@u.user_image).to eql "http://original.com/image_normal.png"
      expect(@u.user_image_original).to eql "http://original.com/image.png"
    end

  end

  it "should incorporate auth.name on normalization" do
    @u.name = nil
    @u.name.blank?.should == true
    auth = GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    @u.authentications << auth

    GT::AuthenticationBuilder.normalize_user_info(@u, auth)

    @u.name.should == "some name"
  end

  context "primary_email" do

    before(:each) do
      @u.primary_email.nil?.should == true
      @auth = GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
      @u.authentications << @auth
    end

    it "should incorporate auth.email on normalization" do
      GT::AuthenticationBuilder.normalize_user_info(@u, @auth)

      @u.primary_email.should == "test@test.com"
    end

    it "should not incorporate auth.email if there is an existing user with that email" do
      other_user = Factory.create(:user, :primary_email => @omniauth_hash['info']['email'])
      other_user.save

      expect {
        GT::AuthenticationBuilder.normalize_user_info(@u, @auth)
      }.not_to change(@u, :primary_email)
    end

  end

  it "should incorporate auth.first_name and auth.last_name on normalization when present" do
    @u.name = nil
    @u.name.blank?.should == true
    @omniauth_hash['info']['first_name'] = "first"
    @omniauth_hash['info']['last_name'] = "last"
    auth = GT::AuthenticationBuilder.build_from_omniauth(@omniauth_hash)
    @u.authentications << auth

    GT::AuthenticationBuilder.normalize_user_info(@u, auth)

    @u.name.should == "first last"
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
