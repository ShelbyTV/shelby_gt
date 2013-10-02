require 'spec_helper'
require 'recommendation_manager'

# INTEGRATION test
describe GT::RecommendationManager do
  before(:each) do
    GT::VideoProviderApi.stub(:get_video_info)
  end

  context "get_video_graph_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = []
      @src_frame_ids = []
      @dbes = []
      # create dashboard entries 0 to n, entry i will have i recommendations attached to its video
      4.times do |i|
        v = Factory.create(:video)
        recs_for_this_video = []
        sharer = Factory.create(:user)
        f = Factory.create(:frame, :video => v, :creator => sharer )

        i.times do |j|
          rec_vid = Factory.create(:video)
          rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
          v.recs << rec
          recs_for_this_video << rec_vid
          @src_frame_ids.unshift f.id
        end

        @recommended_videos.unshift recs_for_this_video

        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :actor => sharer)
        @dbes.unshift dbe
      end

      @recommended_videos.flatten!

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    it "should return all of the recommendations when there are no restricting limits" do
      Array.any_instance.should_receive(:shuffle!).and_call_original

      MongoMapper::Plugins::IdentityMap.clear
      result = @recommendation_manager.get_video_graph_recs_for_user(10, 10)
      result_video_ids = result.map{|rec|rec[:recommended_video_id]}
      result_video_ids.length.should == @recommended_videos.length
      (result_video_ids - @recommended_videos.map { |v| v.id }).should == []
    end

    context "stub shuffle! so we can test everything else more carefully " do

      before(:each) do
        Array.any_instance.stub(:shuffle!)
      end

      it "should return all of the recommendations when there are no restricting limits" do
        MongoMapper::Plugins::IdentityMap.clear
        result = @recommendation_manager.get_video_graph_recs_for_user(10, 10)
        result.length.should == @recommended_videos.length
        result.should == @recommended_videos.each_with_index.map{|vid, i| {:recommended_video_id => vid.id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude videos the user has already watched" do
        @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
        @viewed_roll.frames << @viewed_frame
        MongoMapper::Plugins::IdentityMap.clear

        result = @recommendation_manager.get_video_graph_recs_for_user(10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should exclude videos that are no longer available at the provider" do
        @recommended_videos[0].available = false
        @recommended_videos[0].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @recommendation_manager.get_video_graph_recs_for_user(10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should exclude from consideration dashboard entries that have no actor" do
        @dbes[2].actor_id = nil
        @dbes[2].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @recommendation_manager.get_video_graph_recs_for_user(10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos.last.id, :src_frame_id => @src_frame_ids.last})
        result.should include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
      end

      it "returns the proper number of recs based on the limit parameter" do
        MongoMapper::Plugins::IdentityMap.clear
        @recommendation_manager.get_video_graph_recs_for_user.should == [
          {:recommended_video_id => @dbes.first.video.recs.first.recommended_video_id, :src_frame_id => @dbes.first.frame_id}
        ]
        @recommendation_manager.get_video_graph_recs_for_user(10, 2).should == [
          {:recommended_video_id => @dbes.first.video.recs[0].recommended_video_id, :src_frame_id => @dbes[0].frame_id},
          {:recommended_video_id => @dbes.first.video.recs[1].recommended_video_id, :src_frame_id => @dbes[0].frame_id}
        ]
      end

    end

  end

  context "if_no_recent_recs_generate_rec" do
    before(:each) do
      @user = Factory.create(:user)

      v = Factory.create(:video)
      @rec_vid = Factory.create(:video)
      rec = Factory.create(:recommendation, :recommended_video_id => @rec_vid.id, :score => 100.0)
      v.recs << rec

      sharer = Factory.create(:user)
      @f = Factory.create(:frame, :video => v, :creator => sharer )

      @dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame], :actor => sharer)
    end

    context "no recommendations yet within the recent limit number of frames" do

      it "should return a new dashboard entry with a video graph recommendation if any are available" do
        result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        result.should be_an_instance_of(DashboardEntry)
        result.src_frame.should == @f
        result.video_id.should == @rec_vid.id
        result.action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      end

      it "should create the newest entry in the dashboard by default" do
        result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        result.should == DashboardEntry.sort(:id.desc).first
      end

      it "should insert the newest entry just after a randomly selected dbentry if options[:insert_at_random_locations] is specified" do
        Array.any_instance.stub(:sample).and_return(@dbe)
        result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user, {:insert_at_random_location => true})
        result.id.generation_time.to_i.should == @dbe.id.generation_time.to_i - 1
      end

      context "database peristence" do
        before(:each) do
          @lambda = lambda {
            GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
          }
        end

        it "should persist a new dashboard entry to the database" do
          @lambda.should change { DashboardEntry.count }
        end

        it "should persist a new frame to the database" do
          @lambda.should change { Frame.count }
        end

        it "should persist a conversation because the frame is being persisted" do
          @lambda.should change { Conversation.count }
        end

      end

    end

    context "recommendations exist within the recent limit number of frames" do

      it "should return nil because no new dashboard entries need to be created" do
        # put a recommendation in the dashboard
        GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        # check if we need to put another one
        result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        # since there's already a recommendation in the last five (the one we just created), we shouldn't put another
        result.should be_nil
      end

      it "should not persist any new dashboard entries, frames, or conversations to the database" do
        # put a recommendation in the dashboard
        GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)

        lambda {
          # check if we need to put another one
          GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
          # since there's already a recommendation in the last five (the one we just created), we shouldn't put another
        }.should_not change {"#{DashboardEntry.count},#{Frame.count},#{Conversation.count}"}
      end

    end

  end

  context "create_recommendation_dbentry" do
    before(:each) do
      @user = Factory.create(:user)
      @rec_vid = Factory.create(:video)
    end

    it "should create a db entry for a video graph recommendation with the corresponding video, action, and src_frame" do
      src_frame = Factory.create(:frame)

      result = GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        {
          :src_id => src_frame.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      result[:dashboard_entry].src_frame.should == src_frame

      result[:frame].should be_a Frame
      result[:frame].video.should == @rec_vid
    end

    context "database persistence" do

      context "persist by default" do
        before(:each) do
          @lambda = lambda {
            GT::RecommendationManager.create_recommendation_dbentry(
              @user,
              @rec_vid.id,
              DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
              {
                :src_id => nil
              }
            )
          }
        end

        it "should persist a new dashboard entry to the database" do
          @lambda.should change { DashboardEntry.count }
        end

        it "should persist a new frame to the database" do
          @lambda.should change { Frame.count }
        end

        it "should persist a conversation because the frame is being persisted" do
          @lambda.should change { Conversation.count }
        end
      end

      it "should not persist when persist false option is passed" do
        lambda {
          GT::RecommendationManager.create_recommendation_dbentry(
            @user,
            @rec_vid.id,
            DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
            {
              :src_id => nil,
              :persist => false
            }
          )
        }.should_not change { "#{DashboardEntry.count},#{Frame.count},#{Conversation.count}" }
      end

      context "channel recommendation" do
        context "persist by default" do
          before(:each) do
            src_frame = Factory.create(:frame)
            @lambda = lambda {
              GT::RecommendationManager.create_recommendation_dbentry(
                @user,
                @rec_vid.id,
                DashboardEntry::ENTRY_TYPE[:channel_recommendation],
                {
                  :src_id => src_frame.id
                }
              )
            }
          end

          it "should persist a new dashboard entry to the database" do
            @lambda.should change { DashboardEntry.count }
          end

          it "should not persist a new frame because it's using an existing one" do
            @lambda.should_not change { Frame.count }
          end

          it "should not persist a conversation because a frame is not being persisted" do
            @lambda.should_not change { Conversation.count }
          end
        end

        it "should not persist when persist false option is passed" do
          src_frame = Factory.create(:frame)
          lambda {
            GT::RecommendationManager.create_recommendation_dbentry(
              @user,
              @rec_vid.id,
              DashboardEntry::ENTRY_TYPE[:channel_recommendation],
              {
                :src_id => src_frame.id,
                :persist => false
              }
            )
          }.should_not change { "#{DashboardEntry.count},#{Frame.count},#{Conversation.count}" }
        end
      end

    end

    it "should create a db entry for a mortar recommendation with the corresponding video, action, and src_video" do
      src_video = Factory.create(:video)

      result = GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        {
          :src_id => src_video.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      result[:dashboard_entry].src_video.should == src_video

      result[:frame].should be_a Frame
      result[:frame].video.should == @rec_vid
    end

    it "should create a db entry for a channel recommendation with the corresponding frame, video, and action" do
      src_frame = Factory.create(:frame, :video => @rec_vid)

      result = GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        {
          :src_id => src_frame.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:channel_recommendation]

      result[:frame].should == src_frame
    end
  end

  context "get_mortar_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
      @reason_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]

      GT::MortarHarvester.stub(:get_recs_for_user).and_return([
        {"item_id" => @recommended_videos[0].id.to_s, "reason_id" => @reason_videos[0].id.to_s},
        {"item_id" => @recommended_videos[1].id.to_s, "reason_id" => @reason_videos[1].id.to_s},
        {"item_id" => @recommended_videos[2].id.to_s, "reason_id" => @reason_videos[2].id.to_s}
      ])

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    it "should return the recommended videos" do
      @recommendation_manager.get_mortar_recs_for_user.length.should == 1
      @recommendation_manager.get_mortar_recs_for_user(2).length.should == 2
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame

      @recommendation_manager.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

    it "should skip videos that are no longer available at the provider" do
      @recommended_videos[0].available = false
      @recommended_videos[0].save

      @recommendation_manager.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

  end

  context "get_channel_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
      @channel_user = Factory.create(:user)

      @dbes = []
      @videos = []
      @frames = []
      3.times do
        video = Factory.create(:video)
        @videos.unshift video
        frame = Factory.create(:frame, :video_id => video.id)
        @frames.unshift frame
        @dbes.unshift Factory.create(:dashboard_entry, :user_id => @channel_user.id, :frame_id => frame.id, :video_id => video.id)
      end

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    it "should return the recommended videos" do
      @recommendation_manager.get_channel_recs_for_user(@channel_user.id).length.should == 1
      @recommendation_manager.get_channel_recs_for_user(@channel_user.id, 2).length.should == 2
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame

      @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should skip videos that are no longer available at the provider" do
      @videos[0].available = false
      @videos[0].save

      @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should skip frames that were created by the user for whom recommendations are being generated" do
      @dbes[0].actor_id = @user.id

      @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

  end

  context "get_recs_for_user" do
    before(:each) do
      @user = Factory.create(:user)
      @featured_channel_user = Factory.create(:user)
      Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
      @recommendation_manager = GT::RecommendationManager.new(@user)

      Array.any_instance.stub(:shuffle!)

      #create a video graph rec
      v = Factory.create(:video)
      @vid_graph_recommended_vid = Factory.create(:video)
      rec = Factory.create(:recommendation, :recommended_video_id => @vid_graph_recommended_vid.id, :score => 100.0)
      v.recs << rec

      v.save

      src_frame_creator = Factory.create(:user)
      @vid_graph_src_frame = Factory.create(:frame, :video => v, :creator => src_frame_creator )

      dbe = Factory.create(:dashboard_entry, :frame => @vid_graph_src_frame, :user => @user, :video_id => v.id)

      dbe.save

      #create a mortar rec
      @mortar_recommended_vid = Factory.create(:video)
      @mortar_src_vid = Factory.create(:video)
      mortar_response = [{"item_id" => @mortar_recommended_vid.id.to_s, "reason_id" => @mortar_src_vid.id.to_s}]

      GT::MortarHarvester.stub(:get_recs_for_user).and_return(mortar_response)

      #create a channel rec
      @featured_curator = Factory.create(:user)
      @conversation = Factory.create(:conversation)
      @message = Factory.create(:message, :text => "Some interesting text", :user_id => @featured_curator.id)
      @conversation.messages << @message
      @conversation.save

      @channel_recommended_vid = Factory.create(:video)
      @community_channel_frame = Factory.create(:frame, :creator_id => @featured_curator.id, :video_id => @channel_recommended_vid.id, :conversation_id => @conversation.id)
      @community_channel_dbes = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => @community_channel_frame.id, :video_id => @channel_recommended_vid.id)
    end

    it "returns the right results" do
      MongoMapper::Plugins::IdentityMap.clear

      res = @recommendation_manager.get_recs_for_user({ :sources => [31, 33, 34], :limits => [1, 1, 1] })
      res.length.should == 3
      res[0].should == {
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :recommended_video_id => @vid_graph_recommended_vid.id,
        :src_id => @vid_graph_src_frame.id
      }
      res[1].should == {
        :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        :recommended_video_id => @mortar_recommended_vid.id,
        :src_id => @mortar_src_vid.id
      }
      res[2].should == {
        :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        :recommended_video_id => @channel_recommended_vid.id,
        :src_id => @community_channel_frame.id
      }
    end

  end

  context "filter_recs" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
      @recommendations = @recommended_videos.map {|vid| { :recommended_video_id => vid.id.to_s }}

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    it "return all recs" do
      @recommendation_manager.send(:filter_recs, @recommendations).should == @recommendations
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
    end

    it "should skip videos that are no longer available at the provider" do
      @recommended_videos[0].available = false
      @recommended_videos[0].save

      @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
        @recommendations[1]
      ]
    end

  end

end
