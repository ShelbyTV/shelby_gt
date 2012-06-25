require 'spec_helper' 

describe 'v1/dashboard' do
  context 'logged in' do
    before(:each) do
      @u1 = Factory.create(:user)
      set_omniauth(:uuid => @u1.authentications.first.uid)
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
      
      context "upvoters" do
        before(:each) do
          @f = Factory.create(:frame, :creator_id => @u1.id)
          @d = Factory.build(:dashboard_entry)
          @d.user = @u1
          @d.frame = @f
          @d.save
        end
        
        it "should return an array with upvote users and their attributes" do
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.save
          
          get '/v1/dashboard?include_children=true'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(2).at_path("result/0/frame/upvote_users")
        end

        it "should return an empty array if no upvoters on a frame" do
          get '/v1/dashboard?include_children=true'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(0).at_path("result/0/frame/upvote_users")
        end

        it "should make one single User.find query for all upvoters" do
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.upvoters << Factory.create(:user).id
          @f.save
          
          # 1 time to load current_user
          User.should_receive(:find).exactly(8).times
                      
          get '/v1/dashboard?include_children=true'
        end
      end
      
      it "should return an empty array if limit = 0" do
        get '/v1/dashboard?limit=0'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        parse_json(response.body)["result"].should eq([])
      end
      
      it "should return dashboard entries with a since_id" do
        @f1 = Factory.create(:frame, :creator_id => @u1.id)
        @d1 = Factory.build(:dashboard_entry)
        @d1.user = @u1; @d1.frame = @f1; @d1.save

        @f2 = Factory.create(:frame, :creator_id => @u1.id)
        @d2 = Factory.build(:dashboard_entry)
        @d2.user = @u1; @d2.frame = @f2; @d2.save
        
        @f3 = Factory.create(:frame, :creator_id => @u1.id)
        @d3 = Factory.build(:dashboard_entry)
        @d3.user = @u1; @d3.frame = @f3; @d3.save
                
        get '/v1/dashboard?since_id='+@d2.id.to_s        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(2).at_path("result")
      end
      
      it "should return 404 if non valid id is given" do
        get '/v1/dashboard?since_id=12345'
        response.body.should be_json_eql(404).at_path("status")
        parse_json(response.body)["message"].should eq("invalid since_id 12345")
      end
      
      it "should return 200 if no entries exist" do
        get '/v1/dashboard'
        response.status.should eq(200)
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
      
      it "should return 404 if entry cant be found" do
        put '/v1/dashboard/'+@d.id+'xxx?read=true'
        response.body.should be_json_eql(404).at_path("status")
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