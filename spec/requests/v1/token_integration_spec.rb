require 'spec_helper' 

describe 'v1/token' do
  before(:each) do
    @user = Factory.create(:user, :authentication_token => nil) #adds a twitter authentication
    @twt_auth = @user.authentications[0]
    @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
    @user.authentications << @fb_auth
    @user.save
  end

  context 'creating tokens' do
    
    describe "POST" do
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
    
  end
  
  context "deleting tokens" do
    before(:each) do
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