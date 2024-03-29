require 'spec_helper'

require 'imposter_omniauth'

describe 'v1/token' do

  context 'creating tokens' do

    describe "POST" do

      context "tokens are for: an existing GT real user" do
        before(:each) do
          @user = Factory.create(:user, :authentication_token => nil) #adds a twitter authentication
          @user.password = (@user_password = "password")
          @user.save
          @twt_auth = @user.authentications[0]
          @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
          @user.authentications << @fb_auth
          @user.save
        end

        context "there is no authenticated user" do
          it "should return user info w/ a new auth token on success (with twitter creds)" do
            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
              response.body.should be_json_eql(200).at_path("status")
              response.body.should have_json_path("result/authentication_token")
              parse_json(response.body)['result']['authentication_token'].should == @user.reload.authentication_token
            }.should_not change { User.count }
          end

          it "should not login if intention is signup" do
            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}&intention=signup"
              response.body.should be_json_eql(403).at_path("status")
            }.should_not change { User.count }
          end

          it "should return user info w/ a new auth token on success (with email/password)" do
            lambda {
              post "/v1/token?email=#{@user.primary_email}&password=#{@user_password}"
              response.body.should be_json_eql(200).at_path("status")
              response.body.should have_json_path("result/authentication_token")
              parse_json(response.body)['result']['authentication_token'].should == @user.reload.authentication_token
            }.should_not change { User.count }
          end

          it "should not return a user on 404" do
            post "/v1/token?provider_name=twitter&uid=DNE&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
            response.body.should be_json_eql(404).at_path("status")
            response.body.should_not have_json_path("result/authentication_token")
          end
        end

        context "there is an authenticated user via auth_token" do
          before(:each) do
            @current_user_via_token = Factory.create(:user)
            @current_user_via_token.ensure_authentication_token!
            @current_user_via_token.save
          end

          it "should not merge in a real user (if different from current_user)" do
            @user.user_type.should == User::USER_TYPE[:real]
            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}&auth_token=#{@current_user_via_token.authentication_token}"
              response.body.should be_json_eql(403).at_path("status")
            }.should_not change { User.count }
          end

          it "should update token, secret if matched user is same as current_user" do
            @user.ensure_authentication_token!
            @user.save
            @new_token = "lkjwelrkjlkjer"
            @new_secret = "Asdfasdfasdfasdf"

            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@new_token}&secret=#{@new_secret}&auth_token=#{@user.authentication_token}"
              response.body.should be_json_eql(200).at_path("status")
            }.should_not change { User.count }

            @user.reload
            @user.authentications[0].oauth_token.should == @new_token
            @user.authentications[0].oauth_secret.should == @new_secret
          end
        end
      end

      context "tokens are for: an existing GT faux user" do
        before(:each) do
          @fuser_public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
          @fuser = Factory.create(:user, :authentication_token => nil, :user_type => User::USER_TYPE[:faux], :public_roll => @fuser_public_roll) #adds a twitter authentication
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

        context "there is no authenticated user" do
          it "should convert faux user to real if token/secret match" do
            GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)

            post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_path("result/authentication_token")
            @fuser.reload.user_type.should == User::USER_TYPE[:converted]
          end

          it "should not convert faux user to real if intention is login" do
            GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)

            post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}&intention=login"
            response.body.should be_json_eql(403).at_path("status")
            @fuser.reload.user_type.should == User::USER_TYPE[:faux]
          end

          it "should not convert faux user if token/secret don't match" do
            GT::UserManager.stub(:verify_user).and_return(false)

            post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=BAD_TOKEN&secret=#{@twt_auth.oauth_secret}"
            response.body.should be_json_eql(404).at_path("status")
            response.body.should_not have_json_path("result/authentication_token")
            @fuser.reload.user_type.should == User::USER_TYPE[:faux]
          end
        end

        context "there is an authenticated user via auth_token" do
          before(:each) do
            @current_user_via_token = Factory.create(:user)
            @current_user_via_token.ensure_authentication_token!
            @current_user_via_token.save

            @fuser.authentications[0].oauth_token = nil
            @fuser.authentications[0].oauth_secret = nil
            @fuser.authentications[1].oauth_token = nil
            @fuser.authentications[1].oauth_secret = nil
            @fuser.save(:validate => false)

            @fb_token = "new_fb-tokeno827u354"
          end

          it "should merge in a faux user (if different from current_user)" do
            lambda {
              post "/v1/token?provider_name=facebook&uid=#{@fb_auth.uid}&token=#{@fb_token}&auth_token=#{@current_user_via_token.authentication_token}"

              response.body.should be_json_eql(200).at_path("status")
              #original user returned
              parse_json(response.body)['result']['id'].should == @current_user_via_token.id.to_s
              #with original auth
              parse_json(response.body)['result']['authentications'][0]['provider'].should == "twitter"
              #plus merged in twitter auth
              parse_json(response.body)['result']['authentications'][1]['provider'].should == "twitter"
              parse_json(response.body)['result']['authentications'][1]['uid'].should == @twt_auth.uid
              #plus merged in facebook auth
              parse_json(response.body)['result']['authentications'][2]['provider'].should == "facebook"
              parse_json(response.body)['result']['authentications'][2]['uid'].should == @fb_auth.uid
              #and merged in user is gone
            }.should change { User.count } .by(-1)

            @current_user_via_token.authentications[2].oauth_token.should == @fb_token
          end

          it "should convert an anonymous user" do
            @current_user_via_token.user_type = User::USER_TYPE[:anonymous]
            @current_user_via_token.app_progress = AppProgress.new
            @current_user_via_token.public_roll = public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
            @current_user_via_token.save

            post "/v1/token?provider_name=facebook&uid=#{@fb_auth.uid}&token=#{@fb_token}&auth_token=#{@current_user_via_token.authentication_token}"

            response.body.should be_json_eql(200).at_path("status")

            parsed_response = parse_json(response.body)
            parsed_response['result']['user_type'].should == User::USER_TYPE[:converted]
            parsed_response['result']['app_progress']['onboarding'].should be_true

            public_roll.roll_type.should == Roll::TYPES[:special_public_real_user]
          end
        end
      end

      context "tokens are for: a new user" do
        before(:each) do
          @shelby_roll = Factory.create(:roll, :id => Settings::Roll.shelby_roll_id)
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

        context "there is no authenticated user" do
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

          it "should update app_progress for client: iOS" do
            GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)

            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@uid}&token=#{@oauth_token}&secret=#{@oauth_secret}&client_identifier=iOS_iPhone"
              response.body.should be_json_eql(200).at_path("status")
              response.body.should have_json_path("result/authentication_token")
            }.should change { User.count } .by(1)

            u = User.find_by_nickname(@nickname)
            u.app_progress['onboarding'].should == "iOS_iPhone"

            u.destroy
          end

          it "should not create a new user if action is login" do
            lambda {
              post "/v1/token?provider_name=facebook&uid=#{@uid}&token=#{@oauth_token}&intention=login"
              response.body.should be_json_eql(403).at_path("status")
              response.body.should have_json_path("message/error_code")
              response.body.should_not have_json_path("result/authentication_token")
            }.should_not change { User.count }
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

        context "there is an authenticated user via auth_token" do
          before(:each) do
            @current_user_via_token = Factory.create(:user)
            @current_user_via_token.ensure_authentication_token!
            @current_user_via_token.save

            GT::ImposterOmniauth.stub(:get_user_info).and_return(@omniauth_hash)
          end

          it "should add a new authentication to current user" do

            lambda {
              post "/v1/token?provider_name=twitter&uid=#{@uid}&token=#{@oauth_token}&secret=#{@oauth_secret}&auth_token=#{@current_user_via_token.authentication_token}"
              response.body.should be_json_eql(200).at_path("status")
              response.body.should have_json_path("result/authentication_token")
              parse_json(response.body)['result']['id'].should == @current_user_via_token.id.to_s

              parse_json(response.body)['result']['authentications'].count.should == 2
              parse_json(response.body)['result']['authentications'][1]['provider'].should == "twitter"
              parse_json(response.body)['result']['authentications'][1]['uid'].should == @uid

              @current_user_via_token.reload
              @current_user_via_token.authentications[1].oauth_token.should == @oauth_token
              @current_user_via_token.authentications[1].oauth_secret.should == @oauth_secret
            }.should_not change { User.count }

            u = User.find_by_nickname(@nickname)
            u.should == nil

            @current_user_via_token.destroy
          end

          it "should convert an anonymous user" do
            @current_user_via_token.user_type = User::USER_TYPE[:anonymous]
            @current_user_via_token.app_progress = AppProgress.new
            @current_user_via_token.public_roll = public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
            @current_user_via_token.save

            post "/v1/token?provider_name=twitter&uid=#{@uid}&token=#{@oauth_token}&secret=#{@oauth_secret}&auth_token=#{@current_user_via_token.authentication_token}"

            response.body.should be_json_eql(200).at_path("status")

            parsed_response = parse_json(response.body)
            parsed_response['result']['user_type'].should == User::USER_TYPE[:converted]
            parsed_response['result']['app_progress']['onboarding'].should be_true

            public_roll.roll_type.should == Roll::TYPES[:special_public_real_user]
          end
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