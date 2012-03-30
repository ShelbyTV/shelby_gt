require 'spec_helper' 

describe 'v1/roll' do
  before(:each) do
    @u1 = Factory.create(:user)
    @r = Factory.create(:roll, :creator => @u1)
  end
  
  context 'logged in' do
    before(:each) do
      set_omniauth()
      get '/auth/twitter/callback'
    end
    
    describe "GET" do
      it "should return roll info on success" do
        get '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(@r.title)
      end
    
      it "should return error message if roll doesnt exist" do
        get '/v1/roll/'+@r.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end
      
    end
    
    describe "POST" do
      context "roll creation" do
        it "should create and return a roll on success" do
          post '/v1/roll?title=Roll%20me%20baby&thumbnail_url=http://bar.com'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
          parse_json(response.body)["result"]["title"].should eq("Roll me baby")
          parse_json(response.body)["result"]["thumbnail_url"].should eq("http://bar.com")
        end

        it "should return 404 if there is no thumbnail_url" do
          post '/v1/roll?title=Roll%20me%20baby'      
          response.body.should be_json_eql(404).at_path("status")
        end

        it "should return 404 if there is no title or thumbnail_url" do
          post '/v1/roll'      
          response.body.should be_json_eql(404).at_path("status")
        end        
      end
      
      context "roll sharing" do
        
        it "should return 200 if post is successful" do
          post '/v1/roll/'+@r.id+'/share?destination[]=twitter&comment=testing'
          response.body.should be_json_eql(200).at_path("status")
        end
        
        it "should return 404 if roll not found" do
          post '/v1/roll/'+@r.id+'xxx/share?destination[]=facebook&comment=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("could not find that roll")
        end
        
        it "should return 404 if user cant post to that destination" do
          post '/v1/roll/'+@r.id+'/share?destination[]=facebook&comment=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("that user cant post to that destination")
        end
        
        it "should return 404 if destination not supported" do
          post '/v1/roll/'+@r.id+'/share?destination[]=fake&comment=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("we dont support that destination yet :(")
        end
        
        it "should return 404 if roll is private" do
          @r = Factory.create(:roll, :creator=>@u1, :public => false)
          post '/v1/roll/'+@r.id+'/share?destination[]=twitter&comment=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("that roll is private, can not share")
        end
        
        it "should return 404 if destination and/or comment not incld" do
          post '/v1/roll/'+@r.id+'/share'
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("a destination and a comment is required to post")
        end        
      end
    end
    
    describe "PUT" do
      it "should update and return a roll on success" do
        put '/v1/roll/'+@r.id+'?title=Better%20Title'
      
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["title"].should eq("Better Title")
      end
      
      it "should return an error if a roll cant be found" do
        get '/v1/roll/'+@r.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end

    end
    
    describe "DELETE" do
      it "should delete the frame and return success" do
        delete '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
      end
      
      it "should return an error if a deletion fails" do
        get '/v1/roll/'+@r.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end
      
    end
  end
  
  context "not logged in" do

    describe "GET" do
      it "should return roll info on success" do
        get '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(@r.title)
      end
    
      it "should return error message if roll doesnt exist" do
        get '/v1/roll/'+@r.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end
    end

    describe "All other API Routes besides GET" do
      it "should return 401 Unauthorized" do
        r = Factory.create(:roll, :creator_id => @u1.id)
        delete '/v1/roll/'+r.id
        response.status.should eq(401)
      end
    end
    
  end
  
end