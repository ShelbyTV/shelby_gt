require 'spec_helper' 

describe 'v1/twitter' do
  before(:each) do
    @u1 = Factory.create(:user)
    @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
    @u1.save
    
    #sign that user in
    set_omniauth(:uuid => @u1.authentications.first.uid)
    get '/auth/twitter/callback'
  end
  
  describe "POST" do
    it "should create twitter friendship on /follow route" do
      APIClients::TwitterClient.stub_chain(:build_for_token_and_secret, :friendships, :create!).with(:screen_name => "shelby", :follow => true).and_return(true)
      post '/v1/twitter/follow/shelby'
      response.body.should be_json_eql(200).at_path("status")
    end
  end
  
end