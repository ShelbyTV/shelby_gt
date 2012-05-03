require 'spec_helper' 

describe 'v1/roll' do
  before(:all) do
    @u1 = Factory.create(:user)
    @u2 = Factory.create(:user)
    @u2.downcase_nickname = @u2.nickname.downcase
    @u2.save
    @r = Factory.create(:roll, :creator => @u1)
  end
  
  context 'logged in' do
    before(:all) do
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end
    
    describe "GET" do
      it "should return roll info on success" do
        get '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(@r.title)
      end
      
      it "should return personal roll of user when given a nickname" do
        get 'v1/user/'+@u2.nickname+'/personal_roll'
        response.body.should be_json_eql(200).at_path("status")
      end
    
      it "should return error message if roll doesnt exist" do
        get '/v1/roll/'+@r.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end
      
    end
    
    describe "POST" do
      context "roll creation" do
        it "should create and return a roll on success" do
          post '/v1/roll?title=Roll%20me%20baby&thumbnail_url=http://bar.com&public=0&collaborative=1'

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
        before(:each) do
          resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
          Awesm::Url.stub(:batch).and_return([200, resp])
        end
        
        it "should return 200 if post is successful" do
          post '/v1/roll/'+@r.id+'/share?destination[]=twitter&text=testing'
          response.body.should be_json_eql(200).at_path("status")
        end
        
        it "should return 404 if roll not found" do
          post '/v1/roll/'+@r.id+'xxx/share?destination[]=facebook&text=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("please specify a valid id")
        end
        
        it "should return 404 if user cant post to that destination" do
          post '/v1/roll/'+@r.id+'/share?destination[]=facebook&text=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("that user cant post to that destination")
        end
        
        it "should return 404 if destination not supported" do
          post '/v1/roll/'+@r.id+'/share?destination[]=fake&text=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("we dont support that destination yet :(")
        end
        
        it "should return 404 if roll is private" do
          @r = Factory.create(:roll, :creator=>@u1, :public => false)
          post '/v1/roll/'+@r.id+'/share?destination[]=twitter&text=testing'
          
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("that roll is private, can not share")
        end
        
        it "should return 404 if destination and/or text not incld" do
          post '/v1/roll/'+@r.id+'/share'
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("a destination and a text is required to post")
        end        
      end

      context "join roll" do
        it "should return the roll if it was joined" do
          post '/v1/roll/'+@r.id+'/join'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
        end
        
        it "should return 404 if roll cant be found" do
          post '/v1/roll/'+@r.id+'123/join'
          response.body.should be_json_eql(404).at_path("status")                  
        end
      end
      
      context "leave roll" do
        it "should return the roll if it was left" do
          r = Factory.create(:roll, :creator => @u2, :following_users=>[{:user_id=>@u1.id}])
          post '/v1/roll/'+r.id+'/leave'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
        end

        it "should return 404 if roll can't be left" do
          post '/v1/roll/'+@r.id+'/leave'
          response.body.should be_json_eql(404).at_path("status")                  
        end        
        
        it "should return 404 if roll cant be found" do
          post '/v1/roll/'+@r.id+'123/leave'
          response.body.should be_json_eql(404).at_path("status")                  
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
        r = Factory.create(:roll, :creator_id => @u1.id)
        get '/v1/roll/'+r.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(r.title)
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