require 'spec_helper' 
require 'video_manager'

describe 'v1/frame' do
  
  context 'logged in' do
    before(:all) do
      @u1 = Factory.create(:user)
      @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
      @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
      @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
      @u1.save
      
      @r = Factory.create(:roll, :creator => @u1, :public => false)
      @f = Factory.create(:frame)
      @f2 = Factory.create(:frame)
      @f3 = Factory.create(:frame)
      @f.roll = @r; @f.save
      @f2.roll = @r; @f2.save
      @f3.roll = @r; @f3.save

      set_omniauth(:uuid => @u1.authentications.first.uid)
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
          response.body.should be_json_eql(404).at_path("status")
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
        
        it "should return frame info with a since_id" do
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save
          @f2.roll_id = roll.id; @f2.save
          @f3.roll_id = roll.id; @f3.save
          
          get '/v1/roll/'+roll.id.to_s+'/frames?since_id='+@f2.id.to_s
          
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/creator_id")
          parse_json(response.body)["result"]["creator_id"].should eq(@u1.id.to_s)
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
        end
        
        it "should create and return a frame and success if its payload is a url and text" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return([video])
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
        
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/video_id")
        end
        
        it "should return 404 error if trying to create a frame via url and action is not known" do
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return(video)
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&source=fucked_up'
          
          response.body.should be_json_eql(404).at_path("status")
        end
        
        it "should return 401 if the user is trying to reroll a frame in a roll that is not theirs to roll into" do
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          f = Factory.create(:frame)
          u2 = Factory.create(:user)
          u2.watch_later_roll = Factory.create(:roll, :creator => u2, :public => false)
          u2.save
          post '/v1/roll/'+u2.watch_later_roll_id+'/frames?frame_id='+f.id
          
          response.body.should be_json_eql(401).at_path("status")
        end
        
        it "should return 401 if the user is trying to create a frame in a roll that is not theirs" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return([video])
          u2 = Factory.create(:user)
          u2.watch_later_roll = Factory.create(:roll, :creator => u2, :public => false)
          u2.save
          post '/v1/roll/'+u2.watch_later_roll_id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
          
          response.body.should be_json_eql(401).at_path("status")
        end
      
      end
      
      context 'frame upvoting' do
        it "should return success and frame on upvote" do
          post '/v1/frame/'+@f.id+'/upvote'
          
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
        it "should return 200 if post is successful" do
          post '/v1/frame/'+@f.id+'/share?destination[]=twitter&text=testing'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return 404 if roll not found" do
          post '/v1/frame/'+@f.id+'xxx/share?destination[]=facebook&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("could not find that frame")
        end

        it "should return 404 if user cant post to that destination" do
          post '/v1/frame/'+@f.id+'/share?destination[]=facebook&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("that user cant post to that destination")
        end

        it "should return 404 if destination not supported" do
          post '/v1/frame/'+@f.id+'/share?destination[]=fake&text=testing'

          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("we dont support that destination yet :(")
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
      it "should delete the frame and return success" do
        delete '/v1/frame/'+@f.id
        response.body.should be_json_eql(200).at_path("status")
      end
      
      it "should return an error if a deletion fails" do
        get '/v1/frame/'+@f.id+'xxx'
        response.body.should be_json_eql(404).at_path("status")
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