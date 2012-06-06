require 'spec_helper' 

require 'imposter_omniauth'

describe 'v1/token' do

  context 'creating tokens' do
    
    describe "POST" do
      
      context "existing GT real user" do
        before(:each) do
          @user = Factory.create(:user, :authentication_token => nil) #adds a twitter authentication
          @twt_auth = @user.authentications[0]
          @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
          @user.authentications << @fb_auth
          @user.save
        end
        
        it "should return user info w/ a new auth token on success" do
          post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=#{@twt_auth.oauth_token}&secret=#{@twt_auth.oauth_secret}"
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
          @fuser = Factory.create(:user, :authentication_token => nil, :faux => User::FAUX_STATUS[:true]) #adds a twitter authentication
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
          @fuser.reload.faux.should == User::FAUX_STATUS[:converted]
        end

        it "should not convert faux user if token/secret don't match" do
          GT::UserManager.stub(:verify_user).and_return(false)
          
          post "/v1/token?provider_name=twitter&uid=#{@twt_auth.uid}&token=BAD_TOKEN&secret=#{@twt_auth.oauth_secret}"
          response.body.should be_json_eql(404).at_path("status")
          response.body.should_not have_json_path("result/authentication_token")
          @fuser.reload.faux.should == User::FAUX_STATUS[:true]
        end
      end

      context "new user" do
        before(:each) do
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
        
        it "should create new user if token/secret verify"

        it "should handle bad token/secret and return 404"


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