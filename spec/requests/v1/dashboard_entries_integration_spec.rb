require 'spec_helper' 

describe 'v1/dashboard' do
  context 'logged in' do
    before(:each) do
      MongoMapper::Helper.drop_all_dbs
      @u1 = Factory.create(:user, :authentications => [{:provider => "twitter", :uid => 1234}])

      set_omniauth()
      get '/auth/twitter/callback'      
    end

    describe "GET" do
      it "should return dashboard entry on success" do
        @f = Factory.create(:frame, :creator_id => @u1.id)
        @d = Factory.build(:dashboard_entry)
        @d.user = @u1; @d.frame = @f
        @d.save
        
        get '/v1/dashboard'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        parse_json(response.body)["result"][0]["frame"]["id"].should eq(@f.id.to_s)
      end
      
      it "should return 500 if no entries exist" do
        get '/v1/dashboard'
        response.status.should eq(204)
      end
      
    end
    
    describe "PUT" do
      before(:each) do
        @r = Factory.create(:roll, :creator_id => @u1.id)
        @d = Factory.build(:dashboard_entry)
        @d.user = @u1
        @d.roll = @r
        @d.save
      end
      it "should return dashboard entry on success" do        
        put '/v1/dashboard/'+@d.id+'?read=true'
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        parse_json(response.body)["result"]["read"].should eq(true)
      end
      
      it "should return error if entry update not a success" do
        put '/v1/dashboard/'+@d.id+'?read=donkeybutt'
        
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["read"].should_not eq("donkeybutt")
      end
      
      it "should return 500 if entry cant be found" do
        put '/v1/dashboard/'+@d.id+'xxx?read=true'
        response.body.should be_json_eql(500).at_path("status")
      end
      
    end
    
  end
  
  context "not logged in" do

    describe "All other API Routes besides GET" do
      it "should return 401 Unauthorized" do
        get '/v1/dashboard'
        response.status.should eq(401)
      end
    end
    
  end
  
end