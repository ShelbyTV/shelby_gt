require 'spec_helper'
require 'video_manager'
require 'link_shortener'

describe 'v1/frame' do

  before(:each) do
    @u1 = Factory.create(:user)
    @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
    @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
    @u1.public_roll = Factory.create(:roll, :creator => @u1)
    @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
    @u1.save

    @r = Factory.create(:roll, :creator => @u1, :public => false, :roll_type => Roll::TYPES[:user_private])
    @v = Factory.create(:video, :title => 'title')
    @f = Factory.create(:frame, :creator => @u1, :roll => @r, :conversation => Factory.create(:conversation), :video => @v, :original_source_url => "some_url")
    @f2 = Factory.create(:frame, :creator => @u1, :roll => @r)
    @f3 = Factory.create(:frame, :creator => @u1, :roll => @r)
    @f4 = Factory.create(:frame, :creator => @u1, :roll => @r)
  end

  context 'logged in' do
    before(:each) do
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    describe "GET" do
      context 'one frame' do
        it "should return frame info on success" do
          get '/v1/frame/'+@f.id+'?include_children=true'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/score")
          response.body.should have_json_path("result/frame_type")
          parsed_response = parse_json(response.body)
          parsed_response["result"]["frame_type"].should == Frame::FRAME_TYPE[:heavy_weight]
          parsed_response["result"]["roll"]["roll_type"].should eq(@f.roll.roll_type)
        end

        context "upvote_users" do

          it "should include upvote_users attribute if include_children=true" do
            get '/v1/frame/'+@f.id+'?include_children=true'
            response.body.should have_json_path("result/upvoters")
            response.body.should have_json_type(Array).at_path("result/upvoters")
            response.body.should have_json_size(0).at_path("result/upvoters")
          end

          it "should include the upvote_users data in the correct format if there are any" do
            upvote_user = Factory.create(:user)
            @f.upvoters << upvote_user.id
            @f.save

            get '/v1/frame/'+@f.id+'?include_children=true'
            response.body.should have_json_type(Array).at_path("result/upvoters")
            response.body.should have_json_size(1).at_path("result/upvoters")
            parse_json(response.body)["result"]["upvoters"][0].should eq(upvote_user.id.to_s)
          end

        end

        it "should contain like_count attribute" do
          get '/v1/frame/'+@f.id
          response.body.should have_json_path("result/like_count")
        end

        it "contains original_source_url attribute" do
          get '/v1/frame/'+@f.id
          expect(response.body).to have_json_path("result/original_source_url")
          expect(parse_json(response.body)["result"]["original_source_url"]).to eql "some_url"
        end

        it "contains video's tracked_liker_count attribute" do
          get '/v1/frame/'+@f.id+'?include_children=true'
          response.body.should have_json_path("result/video/tracked_liker_count")
          parse_json(response.body)["result"]["video"]["tracked_liker_count"].should eq(@v.tracked_liker_count)
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
      end

      context 'all frames in a roll' do
        before(:each) do
          @frames_roll = Factory.create(:roll, :creator_id => @u1.id, :roll_type => Roll::TYPES[:user_public])
          @f.roll_id = @frames_roll.id; @f.save
        end

        it "should return frame info on success" do
          Factory.create(:frame, :roll_id => @frames_roll.id)
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

        it "should contain frame upvoters" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_type(Array).at_path("result/frames/0/upvoters")
          response.body.should have_json_size(0).at_path("result/frames/0/upvoters")
        end

        it "should contain frame creator user_type attribute" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/frames/0/creator/user_type")
          parse_json(response.body)["result"]["frames"][0]["creator"]["user_type"].should eq(@u1.user_type)
        end

        it "contains the frame_type attribute" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/frames/0/frame_type")
          parse_json(response.body)["result"]["frames"][0]["frame_type"].should eq(Frame::FRAME_TYPE[:heavy_weight])
        end

        it "should populate frame upvoters with correct data" do
          upvoter1 = Factory.create(:user)
          upvoter2 = Factory.create(:user)
          @f.upvoters << upvoter1.id << upvoter2.id
          @f.save
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(2).at_path("result/frames/0/upvoters")
          parse_json(response.body)["result"]["frames"][0]["upvoters"][0].should eq(upvoter1.id.to_s)
        end

        it "should contain frame like_count" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should have_json_path("result/frames/0/like_count")
          response.body.should have_json_type(Integer).at_path("result/frames/0/like_count")
          parse_json(response.body)["result"]["frames"][0]["like_count"].should eq(0)
        end

        it "should populate frame like_count with correct data" do
          @f.like_count = 2
          @f.save

          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'
          parse_json(response.body)["result"]["frames"][0]["like_count"].should eq(2)
        end

        it "contains video's tracked_liker_count attribute" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          response.body.should have_json_path("result/frames/0/video/tracked_liker_count")
          response.body.should have_json_type(Integer).at_path("result/frames/0/video/tracked_liker_count")
          parse_json(response.body)["result"]["frames"][0]["video"]["tracked_liker_count"].should eq(0)
        end

        it "contains frame's original_source_url attribute" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'

          expect(response.body).to have_json_path("result/frames/0/original_source_url")
          expect(parse_json(response.body)["result"]["frames"][0]["original_source_url"]).to eql "some_url"
        end

        it "should return an empty array when there are no video recommendations" do
          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(0).at_path("result/frames/0/video/recs")
        end

        it "should return a non-empty array when there are video recommendations" do
          @rv = Factory.create(:video)
          @r = Factory.create(:recommendation, :recommended_video_id => @rv.id)
          @v.recs << @r
          @v.save

          get '/v1/roll/'+@frames_roll.id.to_s+'/frames'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(1).at_path("result/frames/0/video/recs")
          parse_json(response.body)["result"]["frames"][0]["video"]["recs"][0]["recommended_video_id"].should eq(@rv.id.to_s)
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

      context 'personal roll' do

        before(:each) do
          @u2 = Factory.create(:user)
          @u2.downcase_nickname = @u2.nickname.downcase
          @u2.save
          @r2 = Factory.create(:roll, :creator => @u2, :public => true)
          @u2.public_roll_id = @r2.id; @u2.save
          @public_roll_frame_1 = Factory.create(:frame, :creator => @u2, :roll_id => @r2.id)
          @public_roll_frame_2 = Factory.create(:frame, :creator => @u2, :roll_id => @r2.id)

          get 'v1/user/'+@u2.id+'/rolls/personal/frames'
        end

        it "should return frames of personal roll of user when given a user id" do
          response.body.should be_json_eql(200).at_path("status")
          response.body.should be_json_eql(2).at_path("result/frame_count")
          response.body.should have_json_size(2).at_path("result/frames")
        end

        it "should return frame's creator user_type attribute for a personal roll" do
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/frames/0/creator/user_type")
          parse_json(response.body)["result"]["frames"][0]["creator"]["user_type"].should eq(@u2.user_type)
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
      before (:each) do
        @hashtag_roll_user = Factory.create(:user)
        Settings::Channels.channels[0]['channel_user_id'] = @hashtag_roll_user.id.to_s
        Settings::Channels.channels[0]['hash_tags'] = ['test', 'testing']
      end

      context 're-rolling' do
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
          response.body.should have_json_path("result/originator_id")
          response.body.should have_json_path("result/originator")
          parse_json(response.body)["result"]["frame_type"].should == Frame::FRAME_TYPE[:heavy_weight]
        end

        it "should add text to the conversation of the newly rolled frame" do
          message_text = "this is my reroll, there are many like it, but this one is mine"
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save
          post '/v1/roll/'+roll.id+'/frames?frame_id='+@f.id+'&text='+CGI::escape(message_text)

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/conversation/messages")
          response.body.should have_json_size(1).at_path("result/conversation/messages")
          parse_json(response.body)["result"]["conversation"]["messages"][0]["text"].should == message_text
        end

        it "should find hashtags and add the frame to the user dashboard" do
          message_text = "this is a #test"
          roll = Factory.create(:roll, :creator_id => @u1.id)
          @f.roll_id = roll.id; @f.save

          lambda {
            post '/v1/roll/'+roll.id+'/frames?frame_id='+@f.id+'&text='+CGI::escape(message_text)
          }.should change { DashboardEntry.count } .by(1)
        end

      end

      context 'frame creation from url' do
        it "should create and return a frame and success if its payload is a url and text" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/video_id")
          parse_json(response.body)["result"]["frame_type"].should == Frame::FRAME_TYPE[:heavy_weight]
        end

        it "should add text to the conversation of the newly created frame" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)
          post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/conversation/messages")
          response.body.should have_json_size(1).at_path("result/conversation/messages")
          parse_json(response.body)["result"]["conversation"]["messages"][0]["text"].should == message_text
        end

        it "doesn't change any liker information if it's not an implicit like" do
          message_text = "awesome video!"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)

          expect {
            post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
          }.not_to change {video.like_count + video.tracked_liker_count + VideoLikerBucket.count}
        end

        it "should find hashtags and add the frame to the user dashboard" do
          message_text = "this is a #test"
          video_url = "http://some.video.url.com/of_a_movie_i_like"
          video = Factory.create(:video, :source_url => video_url)
          GT::VideoManager.stub(:get_or_create_videos_for_url).with(video_url).and_return({:videos=> [video]})
          roll = Factory.create(:roll, :creator_id => @u1.id)

          lambda {
            post '/v1/roll/'+roll.id+'/frames?url='+CGI::escape(video_url)+'&text='+CGI::escape(message_text)
          }.should change { DashboardEntry.count } .by(1)
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

        context "light_weight share/implicit like" do

          before(:each) do
            @message_text = "awesome video!"
            @video_url = "http://some.video.url.com/of_a_movie_i_like"
            @video = Factory.create(:video, :source_url => @video_url)
            GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return({:videos=> [@video]})
          end

          it "adds correct frame_type of light_weight" do
            post '/v1/roll/'+@u1.watch_later_roll.id+'/frames?url='+CGI::escape(@video_url)+'&text='+CGI::escape(@message_text)
            response.body.should be_json_eql(200).at_path("status")
            parse_json(response.body)["result"]["frame_type"].should == Frame::FRAME_TYPE[:light_weight]
          end

          it "adds the frame to the user's personal roll" do
            post '/v1/roll/'+@u1.watch_later_roll.id+'/frames?url='+CGI::escape(@video_url)+'&text='+CGI::escape(@message_text)
            response.body.should be_json_eql(200).at_path("status")
            parse_json(response.body)["result"]["roll_id"].should == @u1.public_roll.id.to_s
          end

          it "updates like_count" do
            expect {
              post '/v1/roll/'+@u1.watch_later_roll.id+'/frames?url='+CGI::escape(@video_url)+'&text='+CGI::escape(@message_text)
            }.to change(@video, :like_count).by(1)
          end

          it "updates tracked_liker_count" do
            expect {
              post '/v1/roll/'+@u1.watch_later_roll.id+'/frames?url='+CGI::escape(@video_url)+'&text='+CGI::escape(@message_text)
            }.to change(@video, :tracked_liker_count).by(1)
          end

          it "records a VideoLiker" do
            expect {
              post '/v1/roll/'+@u1.watch_later_roll.id+'/frames?url='+CGI::escape(@video_url)+'&text='+CGI::escape(@message_text)
            }.to change(VideoLikerBucket, :count).by(1)

            video_liker_bucket = VideoLikerBucket.last
            expect(video_liker_bucket.provider_name).to eq @video.provider_name
            expect(video_liker_bucket.provider_id).to eq @video.provider_id

            video_liker = video_liker_bucket.likers.last
            expect(video_liker.user_id).to eq @u1.id
          end

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
          parse_json(response.body)["result"]["id"].should_not eq(@f.id.to_s)
        end

        it "should call add_to_watch_later! on the frame" do
          dupe_frame = Factory.create(:frame)
          @f.stub(:add_to_watch_later!).and_return(dupe_frame)
          @f.should_receive(:add_to_watch_later!)

          post '/v1/frame/'+@f.id+'/add_to_watch_later'
          parse_json(response.body)["result"]["id"].should eq(dupe_frame.id.to_s)
        end

        it "should return error message if frame doesnt exist" do
          post '/v1/frame/'+@f.id+'xxx/add_to_watch_later'
          response.body.should be_json_eql(404).at_path("status")
        end
      end

      context 'like frame' do
        it "should return success" do
          put '/v1/frame/'+@f.id+'/like'

          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return same frame with like_count incremented" do
          put '/v1/frame/'+@f.id+'/like'

          parse_json(response.body)["result"]["id"].should eq(@f.id.to_s)
          response.body.should be_json_eql(1).at_path("result/like_count")
        end

        it "should return same frame with current user added to upvoters" do
          put '/v1/frame/'+@f.id+'/like'

          response.body.should have_json_size(1).at_path("result/upvoters")
        end

        it "should return originator" do
          @f.frame_ancestors = [@f2.id]
          @f.save

          put '/v1/frame/'+@f.id+'/like'

          response.body.should have_json_path("result/originator_id")
          response.body.should have_json_path("result/originator")
          parse_json(response.body)["result"]["originator"]["id"].should eq(@u1.id.to_s)
        end

        it "should call add_to_watch_later! on the frame but return the original frame" do
          dupe_frame = Factory.create(:frame)
          @f.stub(:add_to_watch_later!).and_return(dupe_frame)
          @f.should_receive(:add_to_watch_later!)

          put '/v1/frame/'+@f.id+'/like'
          parse_json(response.body)["result"]["id"].should eq(@f.id.to_s)
        end

        it "should return error message if frame doesnt exist" do
          put '/v1/frame/'+@f.id+'xxx/like'
          response.body.should be_json_eql(404).at_path("status")
        end
      end

      context "share frame" do
        before(:each) do
          resp = {"awesm_urls" => [
            {"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"},
            {"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_fb", "awesm_id"=>"shl.by_fb", "awesm_url"=>"http://shl.by/fb", "user_id"=>nil, "path"=>"fb", "channel"=>"facebook-post", "domain"=>"shl.by"}
          ]}
          Awesm::Url.stub(:batch).and_return([200, resp])
        end

        it "should return 200 if post is successful" do
          post '/v1/frame/'+@f.id+'/share?destination[]=twitter&text=testing'
          response.body.should be_json_eql(200).at_path("status")
        end

        context "Resque" do
          before(:each) do
            ResqueSpec.reset!
            @u1.stub(:store_autocomplete_info)
            GT::SocialPoster.stub(:post_to_twitter)
            GT::SocialPoster.stub(:post_to_facebook)
            GT::SocialPoster.stub(:email_frame)
          end

          it "shares the frame via twitter" do
            GT::SocialPoster.should_receive(:post_to_twitter).with(@u1, "testing http://shl.by/4")

            post '/v1/frame/'+@f.id+'/share?destination[]=twitter&text=testing'
            ResqueSpec.perform_next(:external_service_share)
          end


          it "shares the frame via facebook" do
            @u1.authentications << FactoryGirl.create(:authentication, :provider => "facebook")
            GT::SocialPoster.should_receive(:post_to_facebook).with(@u1, "testing http://shl.by/fb", @f)

            post '/v1/frame/'+@f.id+'/share?destination[]=facebook&text=testing'
            ResqueSpec.perform_next(:external_service_share)
          end

          it "shares to multiple destinations at once" do
            @u1.authentications << FactoryGirl.create(:authentication, :provider => "facebook")
            GT::SocialPoster.should_receive(:post_to_twitter).with(@u1, "testing http://shl.by/4")
            GT::SocialPoster.should_receive(:post_to_facebook).with(@u1, "testing http://shl.by/fb", @f)

            post '/v1/frame/'+@f.id+'/share?destination[]=twitter&destination[]=facebook&text=testing'
            ResqueSpec.perform_next(:external_service_share)
          end

          it "shares the frame via email" do
            @u1.should_receive(:store_autocomplete_info).with(:email, "spinosa@shelby.tv")
            GT::SocialPoster.should_receive(:email_frame).with(@u1, "spinosa@shelby.tv", "testing", @f)

            post '/v1/frame/'+@f.id+'/share?destination[]=email&addresses=spinosa@shelby.tv&text=testing'
            ResqueSpec.perform_next(:external_service_share)
          end
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

        it "returns 404 if trying to post to email with no email addresses" do
          post '/v1/frame/'+@f.id+'/share?destination[]=email&text=testing'
          response.body.should be_json_eql(404).at_path("status")
          response.body.should have_json_path("message")
          parse_json(response.body)["message"].should eq("you must provide addresses")
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

      it "should *NOT* destroy the Frame's Conversation" do
        @f.conversation.should_not be_nil
        lambda {
          delete '/v1/frame/'+@f.id
        }.should_not change { Conversation.count }
        @f.conversation.reload.should_not == nil
      end

    end

  end

  context "not logged in" do

    it "should return 404 Not Found on SHOW if frame isn't part of public roll" do
      f = Factory.create(:frame, :roll => Factory.create(:roll, :public=>false, :creator=>Factory.create(:user)))
      get '/v1/frame/'+f.id
      response.status.should eq(404)
    end

    describe "POST" do
      context "watched frame" do
        it "should return success and updated frame on watched w/o logged in user"  do
          post '/v1/frame/'+@f.id+'/watched?start_time=1&end_time=44'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/view_count")
          response.body.should be_json_eql(1).at_path("result/view_count")
        end
      end

      context 'like frame' do
        it "should return success" do
          put '/v1/frame/'+@f.id+'/like'

          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return same frame with like_count incremented" do
          put '/v1/frame/'+@f.id+'/like'

          parse_json(response.body)["result"]["id"].should eq(@f.id.to_s)
          response.body.should be_json_eql(1).at_path("result/like_count")
        end

        it "should return same frame without any upvoters added to array" do
          put '/v1/frame/'+@f.id+'/like'

          response.body.should have_json_size(0).at_path("result/upvoters")
        end

        it "should not call add_to_watch_later! on the frame" do
          @f.stub(:add_to_watch_later!).and_return(Factory.create(:frame))
          @f.should_not_receive(:add_to_watch_later!)
          put '/v1/frame/'+@f.id+'/like'
        end

        it "should return error message if frame doesnt exist" do
          put '/v1/frame/'+@f.id+'xxx/like'
          response.body.should be_json_eql(404).at_path("status")
        end
      end
    end

  end

end
