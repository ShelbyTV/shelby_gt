require 'spec_helper' 

describe 'v1/frame' do
  
  context 'logged in' do
    before(:all) do
      @f = Factory.create(:frame)
      @u1 = Factory.create(:user, :authentications => [{:provider => "twitter", :uid => 1234}])
      set_omniauth()
      get '/auth/twitter/callback'
    end
    describe "GET" do
      context 'one frame' do
        it "should return frame info on success" do
          get '/v1/frame/'+@f.id
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
        end
      
        it "should return error message if frame doesnt exist" do
          get '/v1/frame/'+@f.id+'xxx'
          response.body.should be_json_eql(400).at_path("status")
        end
      end
      
      context 'all frames in a roll' do
        it "should return frame info on success" do
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save
          Factory.create(:frame, :roll_id => roll.id)
          get '/v1/roll/'+roll.id.to_s+'/frames'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/creator_id")
          parse_json(response.body)["result"]["creator_id"].should eq(@u1.id.to_s)
          response.body.should have_json_size(2).at_path("result/frames")
        end
      
        it "should return error message if frame doesnt exist" do
          get '/v1/roll/'+@f.id+'xxx/frames'
          response.body.should be_json_eql(400).at_path("status")
        end        
      end
    end
    
    describe "POST" do
      context 'frame creation' do 
        it "should create and return a frame on success" do
          # @f = the frame to be re_rolled
          # roll = the roll to re_roll into
          roll = Factory.create(:roll, :creator_id => @u1.id) 
          @f.roll_id = roll.id; @f.save
          post '/v1/roll/'+roll.id+'/frames?frame_id='+@f.id
        
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
        end
      
      end
      
      context 'frame upvoting' do
        it "should return success and frame on upvote" do
          post '/v1/frame/'+@f.id+'/upvote'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
        end
      end
    end
    
    describe "DELETE" do
      it "should delete the frame and return success" do
        delete '/v1/frame/'+@f.id
        response.body.should be_json_eql(200).at_path("status")
      end
      
      it "should return an error if a deletion fails" do
        get '/v1/frame/'+@f.id+'xxx'
        response.body.should be_json_eql(400).at_path("status")
      end
      
    end
  end
  
  context "not logged in" do

    describe "All API Routes" do
      it "should return 401 Unauthorized" do
        f = Factory.create(:frame)
        get '/v1/frame/'+f.id
        response.status.should eq(401)
      end
    end
    
  end
  
end