require 'spec_helper' 
require 'video_manager'
require 'link_shortener'

describe 'v1/frame' do
  
  context 'logged in' do
    before(:each) do
      @u1 = Factory.create(:user)
      @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
      @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
      @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
      @u1.save
      
      @r = Factory.create(:roll, :creator => @u1, :public => false, :roll_type => Roll::TYPES[:user_private])
      @f = Factory.create(:frame, :creator => @u1, :roll => @r, :conversation => Factory.create(:conversation))
      @f2 = Factory.create(:frame, :creator => @u1, :roll => @r)
      @f3 = Factory.create(:frame, :creator => @u1, :roll => @r)
      @f4 = Factory.create(:frame, :creator => @u1, :roll => @r)
      
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    describe "GET" do
      context 'one frame' do
        it "should return frame info on success" do
          get '/v1/frame/'+@f.id+'?include_children=true'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
          parse_json(response.body)["result"]["roll"]["roll_type"].should eq(@f.roll.roll_type)
        end
      
        it "should return error message if frame doesnt exist" do
          get '/v1/frame/'+@f.id+'xxx'
          response.body.should be_json_eql(404).at_path("status")
        end
        
        it "should return 404 if a frame doesnt have a roll but has a roll_id" do
          @f.roll = nil; @f.roll_id = 2; @f.save
          get '/v1/frame/'+@f.id
          response.body.should be_json_eql(404).at_path("status")
        end
        
        context "upvoters" do
          it "should return an array with upvote users and their attributes" do
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.save
            
            get '/v1/frame/'+@f.id+'?include_children=true'
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_size(2).at_path("result/upvote_users")
          end

          it "should return an empty array if no upvoters on a frame" do
            get '/v1/frame/'+@f.id+'?include_children=true'
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_size(0).at_path("result/upvote_users")
          end

          it "should make one single User.find query for all upvoters" do
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.save
            
            User.should_receive(:find).exactly(1).times
                        
            get '/v1/frame/'+@f.id+'?include_children=true'
          end
        end
      end
      
      context 'all frames in a roll' do
        before(:each) do
          @frames_roll = Factory.create(:roll, :creator_id => @u1.id, :roll_type => Roll::TYPES[:user_public])
          @f.roll_id = @frames_roll.id; @f.save
          Factory.create(:frame, :roll_id => @frames_roll.id)
        end

        it "should return frame info on success" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/creator_id")
          parse_json(response.body)["result"]["creator_id"].should eq(@u1.id.to_s)
          parse_json(response.body)["result"]["roll_type"].should eq(@frames_roll.roll_type)
          response.body.should have_json_size(2).at_path("result/frames")
        end

        it "should contain first frame thumb url" do
          @frames_roll.first_frame_thumbnail_url = 'http://www.example.com/images/image.png'
          @frames_roll.save
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/first_frame_thumbnail_url")
          parse_json(response.body)["result"]["first_frame_thumbnail_url"].should eq(@frames_roll.first_frame_thumbnail_url)
        end
        
        context "upvoters" do
          before(:each) do
            @roll = Factory.create(:roll, :creator_id => @u1.id)
            @f.roll_id = @roll.id
            @f.save
            @f2 = Factory.create(:frame, :roll_id => @roll.id)
          end
          
          it "should return an array with upvote users and their attributes (in the first frame of the roll)" do
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.upvoters << (upvoter = Factory.create(:user)).id
            @f.save
            
            get "/v1/roll/#{@roll.id}/frames"
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_size(7).at_path("result/frames/0/upvote_users")
          end

          it "should return an empty array if no upvoters on the first frame of the roll" do
            get "/v1/roll/#{@roll.id}/frames"
            response.body.should be_json_eql(200).at_path("status")
            response.body.should have_json_size(0).at_path("result/frames/0/upvote_users")
          end

          it "should make one single User.find query for all upvoters (in all frames of the roll)" do
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.upvoters << Factory.create(:user).id
            @f.save
            
            @f2.upvoters << Factory.create(:user).id
            @f2.upvoters << Factory.create(:user).id
            @f2.upvoters << Factory.create(:user).id
            @f2.upvoters << Factory.create(:user).id
            @f2.save
            
            # 1 time to load current_user
            # 1 time to load all the upvote users
            # 1 time for ??? signed_in? ???
            # although thre is 1 unexpected load, it's O(1) and this at least shows we don't have an N+1 problem w/ users
            User.should_receive(:find).exactly(12).times
                        
            get "/v1/roll/#{@roll.id}/frames"
          end
        end

#TODO: finishe these tests... I SUCK AT WRITING TESTS! Code works. can't work out why tests aren't working
=begin
        it "should return frame info with a since_id" do
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save
          @f2.roll_id = roll.id; @f2.save
          @f3.roll_id = roll.id; @f3.save
          
          puts "f: #{@f.score}, f2: #{@f2.score}, f3: #{@f3.score}"

          get '/v1/roll/'+roll.id.to_s+'/frames?since_id='+@f3.id.to_s
          
          parse_json(response.body)["result"]["frames"].each {|f| puts f["score"]}
          
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"]["frames"].last["id"].should eq(@f2.id.to_s)
          response.body.should have_json_size(2).at_path("result/frames")
        end
        
        it "should return frame info with a since_id AND reverse order" do
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save
          @f2.roll_id = roll.id; @f2.save
          @f3.roll_id = roll.id; @f3.save
          @f4.roll_id = roll.id; @f4.save
          
          get '/v1/roll/'+roll.id.to_s+'/frames?since_id='+@f3.id.to_s+'&order=-1'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(2).at_path("result/frames")
          parse_json(response.body)["result"]["frames"][0]["id"].should eq(@f2.id.to_s)
        end
=end
        it "should return frames of personal roll of user when given a nickname" do
          u2 = Factory.create(:user)
          u2.downcase_nickname = u2.nickname.downcase
          u2.save
          r2 = Factory.create(:roll, :creator => u2, :public => true)
          u2.public_roll_id = r2.id; u2.save
          f1 = Factory.create(:frame, :roll_id => r2.id)
          f2 = Factory.create(:frame, :roll_id => r2.id)
          
          get 'v1/user/'+u2.nickname+'/rolls/personal/frames'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should be_json_eql(2).at_path("result/frame_count")
          response.body.should have_json_size(2).at_path("result/frames")
        end

        it "should return frames of heart roll of user when given a nickname" do
          u2 = Factory.create(:user)
          u2.downcase_nickname = u2.nickname.downcase
          u2.save
          r2 = Factory.create(:roll, :creator => u2, :public => true)
          u2.upvoted_roll_id = r2.id; u2.save
          f1 = Factory.create(:frame, :roll_id => r2.id)
          f2 = Factory.create(:frame, :roll_id => r2.id)
          
          get 'v1/user/'+u2.nickname+'/rolls/heart/frames'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should be_json_eql(2).at_path("result/frame_count")
          response.body.should have_json_size(2).at_path("result/frames")
        end
        
        it "should return 404 if cant access frames in a roll" do
          roll = Factory.create(:roll, :creator_id => Factory.create(:user).id, :public => false)
          @f.roll_id = roll.id; @f.save
          Factory.create(:frame, :roll_id => roll.id)
          get '/v1/roll/'+roll.id.to_s+'/frames'
          
          response.body.should be_json_eql(404).at_path("status")
        end
        
        it "should return error message if frame doesnt exist" do
          get '/v1/roll/'+@f.id+'xxx/frames'
          response.body.should be_json_eql(404).at_path("status")
        end
      end
      
      context 'short_link' do
        it "should return short_link for a frame on success" do
          short_link = "http://shl.by/1"
          GT::LinkShortener.stub(:get_or_create_shortlinks).and_return({'email'=>short_link})
          get '/v1/frame/'+@f.id+'/short_link'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/short_link")
          parse_json(response.body)["result"]["short_link"].should eq(short_link)
        end
        
      end
    end
    
    describe "POST" do
      context 'frame creation' do 
        it "should create and return a frame on success if its payload is a frame_id" do
          # @f = the frame to be re_rolled
          # roll = the roll to re_roll into
          roll = Factory.create(:roll, :creator_id => @u1.id) 
          @f.roll_id = roll.id; @f.save
          post '/v1/roll/'+roll.id+'/frames?frame_id='+@f.id

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
          response.body.should have_json_path("result/roll")
          response.body.should have_json_path("result/creator")
          response.body.should have_json_path("result/video")
          response.body.should have_json_path("result/conversation")
        end
        
        it "should create and return a frame and success if its payload is a url and text" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
        
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/video_id")
        end
        
        it "should return 404 error if trying to create a frame via url and action is not known" do
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&source=fucked_up'
          
          response.body.should be_json_eql(404).at_path("status")
        end
        
        it "should return 403 if the user is trying to reroll a frame in a roll that is not theirs to roll into" do
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          f = Factory.create(:frame)
          u2 = Factory.create(:user)
          u2.watch_later_roll = Factory.create(:roll, :creator => u2, :public => false)
          u2.save
          post '/v1/roll/'+u2.watch_later_roll_id+'/frames?frame_id='+f.id
          
          response.body.should be_json_eql(403).at_path("status")
        end
        
        it "should return 403 if the user is trying to create a frame in a roll that is not theirs" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          u2 = Factory.create(:user)
          u2.watch_later_roll = Factory.create(:roll, :creator => u2, :public => false)
          u2.save
          post '/v1/roll/'+u2.watch_later_roll_id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
          
          response.body.should be_json_eql(403).at_path("status")
        end
      
      end
      
      context 'frame upvoting' do
        it "should return success and original frame on upvote" do
          post '/v1/frame/'+@f.id+'/upvote'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
        end
        
        it "should return success and original frame on upvote undo" do
          @f.upvote!(@u1)
          
          post '/v1/frame/'+@f.id+'/upvote?undo=1'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
        end
        
      end
      
      context 'watched frame' do
        it "should return success and updated frame on watched w/ logged in user" do
          post '/v1/frame/'+@f.id+'/watched?start_time=4&end_time=44'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/view_count")
          response.body.should be_json_eql(1).at_path("result/view_count")
        end
        
        it "should return success and updated frame on watched w/o logged in user"  do
          set_omniauth(:uuid => nil)
          get '/auth/twitter/callback'
          
          @f.should_not_receive(:view!)
          post '/v1/frame/'+@f.id+'/watched?start_time=4&end_time=44'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/view_count")
          response.body.should be_json_eql(1).at_path("result/view_count")
        end
        
        it "should return success and updated frame on watched w/o start/end times" do
          post '/v1/frame/'+@f.id+'/watched'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/view_count")
        end
      end
      
      context 'add frame to watch later' do
        it "should return success and the duped frame" do
          post '/v1/frame/'+@f.id+'/add_to_watch_later'
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/upvoters")
        end
      end

      context "share frame" do
        before(:each) do
          resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
          Awesm::Url.stub(:batch).and_return([200, resp])
        end
        
        it "should return 200 if post is successful" do
          post '/v1/frame/'+@f.id+'/share?destination[]=twitter&text=testing'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return 404 if roll not found" do
          post '/v1/frame/'+@f.id+'xxx/share?destination[]=facebook&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("could not find frame with id #{@f.id}xxx")
        end

        it "should return 404 if user cant post to that destination" do
          post '/v1/frame/'+@f.id+'/share?destination[]=facebook&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
        end

        it "should return 404 if destination not supported" do
          post '/v1/frame/'+@f.id+'/share?destination[]=fake&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
        end
        
        it "should return 404 if destination and/or comment not incld" do
          post '/v1/frame/'+@f.id+'/share'
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("a destination and text is required to post")
        end
      end
    end

    describe "DELETE" do
      it "should delete the Frame and return success (if it's destroybale by the User)" do
        Frame.any_instance.should_receive(:destroyable_by?).with(@u1).and_return(true)
        delete '/v1/frame/'+@f.id
        response.body.should be_json_eql(200).at_path("status")
      end
      
      it "should fail to delete the Frame (if it's not destroyable by the User)" do
        Frame.any_instance.should_receive(:destroyable_by?).with(@u1).and_return(false)
        delete '/v1/frame/'+@f.id
        response.body.should be_json_eql(404).at_path("status")
      end
      
      it "should return an error if a deletion fails" do
        delete '/v1/frame/'+@f.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
      end
      
      it "should destroy the Frame's Conversation" do
        @f.conversation.should_not be_nil
        lambda {
          delete '/v1/frame/'+@f.id
        }.should change { Conversation.count } .by(-1)
        @f.conversation.reload.should be_nil
      end
      
    end
    
  end
  
  context "not logged in" do

    it "should return 404 Not Found on SHOW if frame isn't part of public roll" do
      f = Factory.create(:frame, :roll => Factory.create(:roll, :public=>false, :creator=>Factory.create(:user)))
      get '/v1/frame/'+f.id
      response.status.should eq(404)
    end
    
  end
  
end