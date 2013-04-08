require 'spec_helper'

require 'imposter_omniauth'

describe 'v1/token' do

  context 'creating tokens' do

    describe "POST" do

      context "existing GT real user" do
        before(:each) do
          @user = Factory.create(:user, :authentication_token => nil) #adds a twitter authentication
          @user.password = (@user_password = "password")
          @user.save
          @twt_auth = @user.authentications[0]
          @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
          @user.authentications << @fb_auth
          @user.save
        end

        it "should return user info w/ a new auth token on success (with twitter creds)" do
          post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/authentication_token")
          parse_json(response.body)['result']['authentication_token'].should == @user.reload.authentication_token
        end

        it "should return user info w/ a new auth token on success (with email/password)" do
          post "/v1/token?email=#{@user.primary_email}&password=#{@user_password}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/authentication_token")
          parse_json(response.body)['result']['authentication_token'].should == @user.reload.authentication_token
        end

        it "should not return a user on 404" do
          post "/v1/token?provider_name=twitter&uid=DNE&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
          response.body.should be_json_eql(404).at_path("status")
          response.body.should_not have_json_path("result/authentication_token")
        end
      end

      context "existing GT faux user" do
        before(:each) do
          @fuser = Factory.create(:user, :authentication_token => nil, :user_type => User::USER_TYPE[:faux]) #adds a twitter authentication
          @twt_auth = @fuser.authentications[0]
          @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
          @fuser.authentications << @fb_auth
          @fuser.save

          @omniauth_hash = {
            'provider' => "twitter",
            'uid' => @twt_auth.uid,
            'credentials' => {
              'token' => @twt_auth.oauth_token,
              'secret' => @twt_auth.oauth_secret
            },
            'info' => {
              'name' => @twt_auth.name,
              'nickname' => @twt_auth.nickname,
              'image' => "http://original.com/image_normal.png"
            }
          }
        end

        it "should convert faux user to real if token/secret match" do
          GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)

          post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/authentication_token")
          @fuser.reload.user_type.should == User::USER_TYPE[:converted]
        end

        it "should not convert faux user if token/secret don't match" do
          GT::UserManager.stub(:verify_user).and_return(false)

          post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=BAD_TOKEN&secret=#{@twt_auth.oauth_secret}"
          response.body.should be_json_eql(404).at_path("status")
          response.body.should_not have_json_path("result/authentication_token")
          @fuser.reload.user_type.should == User::USER_TYPE[:faux]
        end
      end

      context "new user" do
        before(:each) do
          @uid, @oauth_token, @oauth_secret, @name, @nickname = "123uid", "oaTok", "oaSec", "name", "someNickname--is--unique"

          @omniauth_hash = {
            'provider' => "twitter",
            'uid' => @uid,
            'credentials' => {
              'token' => @oauth_token,
              'secret' => @oauth_secret
            },
            'info' => {
              'name' => @name,
              'nickname' => @nickname,
              'image' => "http://original.com/image_normal.png"
            }
          }
        end

        it "should create new user if token/secret verify" do
          GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)

          lambda {
            post "/v1/token?provider_name=twitter&uid=#{@uid}&token=#{@oauth_token}&secret=#{@oauth_secret}"
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_path("result/authentication_token")
          }.should change { User.count } .by(1)

          u = User.find_by_nickname(@nickname)
          u.nickname.should == @nickname
          u.name.should == @name
          u.authentications.size.should == 1
          u.authentications[0].provider.should == "twitter"
          u.authentications[0].uid.should == @uid
          u.authentications[0].oauth_token.should == @oauth_token
          u.authentications[0].oauth_secret.should == @oauth_secret

          u.destroy
        end

        it "should handle bad token/secret and return 404" do
          GT::ImposterOmniauth.stub(:get_user_info).and_return({})

          lambda {
            post "/v1/token?provider_name=twitter&uid=#{@uid}&token=NOT_THE_TOKEN&secret=#{@oauth_secret}"
            response.body.should be_json_eql(404).at_path("status")
            response.body.should_not have_json_path("result/authentication_token")
          }.should change { User.count } .by(0)
        end


      end
    end

  end

  context "deleting tokens" do
    before(:each) do
      @user = Factory.create(:user, :authentication_token => nil) #adds a twitter authentication
      @twt_auth = @user.authentications[0]
      @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
      @user.authentications << @fb_auth
      @user.authentication_token = "some_auth_token"
      @user.save
    end

    describe "DESTROY" do
      it "should return user info w/ nil auth token on success" do
        delete "/v1/token/#{@user.authentication_token}"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")
        response.body.should_not have_json_path("result/authentication_token")
      end

      it "should not return a user on 404" do
        delete "/v1/token/not_the_token"
        response.body.should be_json_eql(404).at_path("status")
        response.body.should_not have_json_path("result/authentication_token")
      end
    end

  end
end