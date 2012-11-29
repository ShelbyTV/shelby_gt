# encoding: UTF-8
require 'spec_helper' 

describe 'v1/roll' do
  before(:each) do
    @u1 = Factory.create(:user)
    @uv_roll1 = Factory.create(:roll, :creator => @u1)
    @pub_roll1 = Factory.create(:roll, :creator => @u1)
    @u1.public_roll = @pub_roll1
    @u1.upvoted_roll = @uv_roll1
    @u1.save
    
    
    @u2 = Factory.create(:user)
    @uv_roll2 = Factory.build(:roll, :creator => @u2, :upvoted_roll => true)
    @pub_roll2 = Factory.build(:roll, :creator => @u2)
    @u2.public_roll = @pub_roll2
    @u2.upvoted_roll = @uv_roll2
    @u2.downcase_nickname = @u2.nickname.downcase
    @u2.save
    @r = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:global_public])
  end
  
  context 'logged in' do
    before(:each) do
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    describe "GET index" do
      it "should return array containing the one desired roll on success" do
        @r.roll_type = Roll::TYPES[:special_public_real_user]
        @r.save
        get "/v1/roll?subdomain=#{@r.subdomain}"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        response.body.should have_json_size(1).at_path("result")
        parse_json(response.body)["result"][0]["id"].should eq(@r.id.to_s)
      end

      context "authorization" do
        before(:each) do
          Roll.stub_chain(:where, :all).and_return([@r])
          @r.roll_type = Roll::TYPES[:special_public_real_user]
        end

        it "should not return private rolls where user has no special viewing priviledges" do
          @r.public = false
          @r.save

          @r.stub(:viewable_by?).and_return(false)
          get "/v1/roll?subdomain=#{@r.subdomain}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(0).at_path("result")
        end

        it "should return private rolls where user has special viewing priviledges" do
          @r.public = false
          @r.save

          @r.stub(:viewable_by?).and_return(true)
          get "/v1/roll?subdomain=#{@r.subdomain}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(1).at_path("result")
          parse_json(response.body)["result"][0]["id"].should eq(@r.id.to_s)
        end

        it "should return public rolls even if user has no special viewing priviledges" do
          @r.public = true
          @r.save

          @r.stub(:viewable_by?).and_return(false)
          get "/v1/roll?subdomain=#{@r.subdomain}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(1).at_path("result")
          parse_json(response.body)["result"][0]["id"].should eq(@r.id.to_s)
        end
      end

      it "should return an empty array if the desired subdomain is not found" do
        @r.roll_type = Roll::TYPES[:special_public_real_user]
        @r.save
        get "/v1/roll?subdomain=someothersubdomain"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        response.body.should have_json_size(0).at_path("result")
      end

      it "should return 400 if subdomain param not included" do
        get '/v1/roll'
        response.body.should be_json_eql(400).at_path("status")
        response.body.should have_json_path("message")
        parse_json(response.body)["message"].should eq("required parameter subdomain not specified")
      end
    end

    describe "GET show" do
      it "should return roll info on success" do
        get '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(@r.title)
        parse_json(response.body)["result"]["roll_type"].should eq(@r.roll_type)
        parse_json(response.body)["result"]["followed_at"].should == 0 #b/c user is not following
      end
      
      it "should return followed at if use is following roll" do
        r = Factory.create(:roll, :creator => @u1)
        r.add_follower(@u1)
        
        get '/v1/roll/'+r.id
        response.body.should be_json_eql(200).at_path("status")
        
        parse_json(response.body)["result"]["followed_at"].should == @u1.reload.roll_following_for(r).id.generation_time.to_f
      end
      
      it "should not return subdomain unless subdomain_active" do
        get '/v1/roll/'+@r.id
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["subdomain"].should == nil
      end
      
      it "shoud return subdomain when subdomain_active" do
        r = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:global_public], :subdomain => "thesubd", :subdomain_active => true, :collaborative => false)
        get '/v1/roll/'+r.id
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["subdomain"].should == r.subdomain
      end
      
      it "should return roll info on success when looking up by subdomain if the subdomain is active" do
        @r.roll_type = Roll::TYPES[:special_public_real_user]
        @r.collaborative = false
        @r.save
        get '/v1/roll/'+@r.subdomain
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/title")
        parse_json(response.body)["result"]["title"].should eq(@r.title)
      end

      it "should return error message when looking up by subdomain if the subdomain is not active" do
        @r.collaborative = true
        @r.save
        get '/v1/roll/'+@r.title
        response.body.should be_json_eql(404).at_path("status")
      end

      it "should return error message when looking up by subdomain if there is no roll with that subdomain" do
        get '/v1/roll/nonexistantsubdomain'
        response.body.should be_json_eql(404).at_path("status")
      end

      it "should return personal roll of user when given a nickname" do
        get 'v1/user/'+@u2.nickname+'/rolls/personal'
        response.body.should be_json_eql(200).at_path("status")
      end

      it "should return error message if roll doesnt exist" do
        get '/v1/roll/'+ BSON::ObjectId.new.to_s
        response.body.should be_json_eql(404).at_path("status")
      end      
    end
    
    describe "GET featured" do
      it "should return an array of objects" do
        get 'v1/roll/featured'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::Roll.featured.size).at_path("result")
      end
      
      it "should return all the categories" do
        get 'v1/roll/featured'
        response.body.should have_json_path("result/0/category_title")
        response.body.should have_json_path("result/0/include_in")
        response.body.should have_json_path("result/0/rolls/0/display_title")
        response.body.should have_json_path("result/0/rolls/0/id")
      end
      
      it "should return just onboarding categories" do
        get 'v1/roll/featured?segment=onboarding'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::Roll.featured.select { |r| r["include_in"]["onboarding"] }.size).at_path("result")
        response.body.should_not have_json_path("result/0/include_in")
        response.body.should have_json_path("result/0/rolls/0/display_thumbnail_src")
      end
      
      it "should return just explore categories" do
        get 'v1/roll/featured?segment=explore'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::Roll.featured.select { |r| r["include_in"]["explore"] }.size).at_path("result")
      end

      it "should return just in_line_promos categories" do
        get 'v1/roll/featured?segment=in_line_promos'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::Roll.featured.select { |r| r["include_in"]["in_line_promos"] }.size).at_path("result")
      end
    end

    describe "GET Explore" do
      before(:each) do
        @v1, @v2 = Factory.create(:video), Factory.create(:video)
        #Video.stub(:find).and_return([@v1, @v2])
        @r1, @r2 = Factory.create(:roll), Factory.create(:roll)
        Roll.stub(:find).and_return([@r1, @r2])
        @f1_1, @f1_2, @f1_3 = Factory.create(:frame, :roll => @r1, :video => @v1, :creator => @u1), Factory.create(:frame, :roll => @r1, :video => @v2, :creator => @u1), Factory.create(:frame, :roll => @r1, :video => @v2, :creator => @u1)
        @f2_1, @f2_2, @f2_3 = Factory.create(:frame, :roll => @r2, :video => @v1, :creator => @u1), Factory.create(:frame, :roll => @r2, :video => @v2, :creator => @u1), Factory.create(:frame, :roll => @r2, :video => @v2, :creator => @u1)
      end
      
      it "should return an array of objects" do
        get 'v1/roll/explore'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::Roll.explore.size).at_path("result")
      end
      
      it "should include the category name for each object" do
        get 'v1/roll/explore'
        response.body.should have_json_path("result/0/category")
      end
      
      it "should include a rolls array for each object" do
        get 'v1/roll/explore'
        response.body.should have_json_path("result/0/rolls")
      end
      
      it "should include three frames for each Roll in the rolls array" do
        get 'v1/roll/explore'
        response.body.should have_json_size(3).at_path("result/0/rolls/0/frames")
        response.body.should have_json_size(3).at_path("result/1/rolls/0/frames")
        response.body.should have_json_size(3).at_path("result/1/rolls/1/frames")
      end
      
      it "should include each frame's creator's id and nickname" do
        get 'v1/roll/explore'
        response.body.should have_json_path("result/0/rolls/0/frames/0/creator")
        response.body.should have_json_path("result/0/rolls/0/frames/0/creator/id")
        response.body.should have_json_path("result/0/rolls/0/frames/0/creator/nickname")

        parse_json(response.body)["result"][0]["rolls"][0]["frames"][0]["creator"]["id"].should eq(@u1.id.to_s)
        parse_json(response.body)["result"][0]["rolls"][0]["frames"][0]["creator"]["nickname"].should eq(@u1.nickname)
      end

      it "should only call find on Videos once" do
        Video.should_receive(:find).exactly(1).times
        get 'v1/roll/explore'
      end
      
    end
    
    describe "POST" do
      context "roll creation" do
        it "should create and return a private roll on success" do
          post '/v1/roll?title=Roll%20me%20baby&thumbnail_url=http://bar.com&public=0&collaborative=1'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
          parse_json(response.body)["result"]["title"].should eq("Roll me baby")
          parse_json(response.body)["result"]["creator_nickname"].should eq(@u1.nickname)
          parse_json(response.body)["result"]["thumbnail_url"].should eq("http://bar.com")
          parse_json(response.body)["result"]["roll_type"].should eq(Roll::TYPES[:user_private])
          parse_json(response.body)["result"]["followed_at"].should == @u1.reload.roll_following_for(Roll.sort(:_id=>-1).first).id.generation_time.to_f
        end
        
        it "should create and return a public on success" do
          post '/v1/roll?title=Roll%20me%20baby&thumbnail_url=http://bar.com&public=1&collaborative=0'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
          parse_json(response.body)["result"]["title"].should eq("Roll me baby")
          parse_json(response.body)["result"]["thumbnail_url"].should eq("http://bar.com")
          parse_json(response.body)["result"]["roll_type"].should eq(Roll::TYPES[:user_public])
        end

        it "should return 400 if there is no thumbnail_url" do
          post '/v1/roll?title=Roll%20me%20baby'      
          response.body.should be_json_eql(400).at_path("status")
        end

        it "should return 400 if there is no title or thumbnail_url" do
          post '/v1/roll'      
          response.body.should be_json_eql(400).at_path("status")
        end

        it "should return 409 if trying to set a reserved subdomain" do
          Roll.any_instance.stub(:has_subdomain_access?).and_return(true)
          
          post '/v1/roll?title=anal&thumbnail_url=http://bar.com&public=1&collaborative=0'
          response.body.should be_json_eql(409).at_path("status")
        end
      end
      
      context "roll sharing" do
        before(:each) do
          resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
          Awesm::Url.stub(:batch).and_return([200, resp])
        end
        
        context "social share" do
          it "should return 200 if post is successful" do
            post '/v1/roll/'+@r.id+'/share?destination[]=twitter&text=testing'
            response.body.should be_json_eql(200).at_path("status")
          end
        
          it "should return 404 if roll not found" do
            post '/v1/roll/'+@r.id+'xxx/share?destination[]=facebook&text=testing'
          
            response.body.should be_json_eql(404).at_path("status")
            response.body.should have_json_path("message")
            parse_json(response.body)["message"].should eq("could not find roll with id #{@r.id}xxx")
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
          end
        
          it "should return 404 if destination and/or text not incld" do
            post '/v1/roll/'+@r.id+'/share'
            response.body.should be_json_eql(404).at_path("status")
            response.body.should have_json_path("message")
            parse_json(response.body)["message"].should eq("a destination and a text is required to post")
          end
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

      it "should return 409 if trying to set a reserved subdomain" do
        Roll.any_instance.stub(:has_subdomain_access?).and_return(true)
        
        @r.collaborative = false
        @r.save
        put '/v1/roll/'+@r.id+'?title=anal'
        response.body.should be_json_eql(409).at_path("status")
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

    describe "GET show" do
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
    
    describe "GET show_associated" do
      it "should return roll info on success (and put requested roll at start of array)" do
        u = Factory.create(:user)
        r1 = Factory.create(:roll, :creator_id => u.id, :public => true, :roll_type => Roll::TYPES[:user_public])
        r2 = Factory.create(:roll, :creator_id => u.id, :public => true, :roll_type => Roll::TYPES[:user_public])
        r3 = Factory.create(:roll, :creator_id => u.id, :public => true, :roll_type => Roll::TYPES[:user_public])
        r_private = Factory.create(:roll, :creator_id => u.id, :public => false, :roll_type => Roll::TYPES[:user_private])
        r_hearted = Factory.create(:roll, :creator_id => u.id, :public => true, :roll_type => Roll::TYPES[:special_upvoted])
        get '/v1/roll/'+r2.id+'/associated'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/rolls")
        response.body.should have_json_size(3).at_path("result/rolls")
        parse_json(response.body)["result"]["rolls"][0]["title"].should eq(r2.title)
      end
    end

    describe "GET index" do
      before (:each) do
        @r.roll_type = Roll::TYPES[:special_public_real_user]
        Roll.stub_chain(:where, :all).and_return([@r])
      end

      it "should return array containing the one desired roll for a public roll" do
        @r.public = true
        @r.save

        get "/v1/roll?subdomain=#{@r.subdomain}"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        response.body.should have_json_size(1).at_path("result")
        parse_json(response.body)["result"][0]["id"].should eq(@r.id.to_s)
      end

      it "should not return private rolls" do
          @r.public = false
          @r.save

          @r.stub(:viewable_by?).and_return(false)
          get "/v1/roll?subdomain=#{@r.subdomain}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(0).at_path("result")
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
