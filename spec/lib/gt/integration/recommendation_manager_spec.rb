require 'spec_helper'
require 'recommendation_manager'

# INTEGRATION test
describe GT::RecommendationManager do
  before(:each) do
    GT::VideoManager.stub(:update_video_info)
  end

  context "get_random_video_graph_recs_for_user" do
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
        f = Factory.create(:frame, :video => v, :creator => @user )

        i.times do |j|
          rec_vid = Factory.create(:video)
          rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
          v.recs << rec
          recs_for_this_video << rec_vid
          @src_frame_ids.unshift f.id
        end

        @recommended_videos.unshift recs_for_this_video

        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
        @dbes.unshift dbe
      end

      @recommended_videos.flatten!
    end

    it "should return all of the recommendations when there are no restricting limits" do
      Array.any_instance.should_receive(:shuffle!).and_call_original

      MongoMapper::Plugins::IdentityMap.clear
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
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
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_videos.length
        result.should == @recommended_videos.each_with_index.map{|vid, i| {:recommended_video_id => vid.id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude videos the user has already watched" do
        @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
        @viewed_roll.frames << @viewed_frame

        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should exclude videos that are no longer available at the provider" do
        MongoMapper::Plugins::IdentityMap.clear
        @recommended_videos[0].available = false
        @recommended_videos[0].save

        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "shoud exclude from consideration dashboard entries that are recommendations themselves" do
        MongoMapper::Plugins::IdentityMap.clear
        @dbes[2].action = DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        @dbes[2].save

        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos.last.id, :src_frame_id => @src_frame_ids.last})
        result.should include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
      end

      it "should return only one recommended video by default" do
        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user)
        result.should == [{:recommended_video_id => @dbes.first.video.recs.first.recommended_video_id, :src_frame_id => @dbes.first.frame_id}]
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

      @f = Factory.create(:frame, :video => v, :creator => @user )

      @dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
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
  end

  context "get_mortar_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_video = Factory.create(:video)
      @reason_video = Factory.create(:video)

      GT::MortarHarvester.stub(:get_recs_for_user).and_return([{"item_id" => @recommended_video.id.to_s, "reason_id" => @reason_video.id.to_s}])
    end

    it "should return the recommended videos" do
      GT::RecommendationManager.get_mortar_recs_for_user(@user).length.should == 1
    end

    it "should exclude videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @recommended_video.id, :creator => @user)
      @viewed_roll.frames << @viewed_frame

      GT::RecommendationManager.get_mortar_recs_for_user(@user).should == []
    end

    it "should exclude videos that are no longer available at the provider" do
      @recommended_video.available = false
      @recommended_video.save

      GT::RecommendationManager.get_mortar_recs_for_user(@user).should == []
    end

  end

end
