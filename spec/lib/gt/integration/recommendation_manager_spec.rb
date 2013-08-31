require 'spec_helper'
require 'recommendation_manager'

# INTEGRATION test
describe GT::RecommendationManager do

  context "get_random_video_graph_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_video_ids = []
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
          recs_for_this_video << rec_vid.id
          @src_frame_ids.unshift f.id
        end

        @recommended_video_ids.unshift recs_for_this_video

        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
        @dbes.unshift dbe
      end

      @recommended_video_ids.flatten!
    end

    it "should return all of the recommendations when there are no restricting limits" do
      Array.any_instance.should_receive(:shuffle!).and_call_original

      MongoMapper::Plugins::IdentityMap.clear
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
      result_video_ids = result.map{|rec|rec[:recommended_video_id]}
      result_video_ids.length.should == @recommended_video_ids.length
      (result_video_ids - @recommended_video_ids).should == []
    end

    context "stub shuffle! so we can test everything else more carefully " do

      before(:each) do
        Array.any_instance.stub(:shuffle!)
      end

      it "should return all of the recommendations when there are no restricting limits" do
        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_video_ids.length
        result.should == @recommended_video_ids.each_with_index.map{|id, i| {:recommended_video_id => id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude videos the user has already watched" do
        @viewed_frame = Factory.create(:frame, :video_id => @recommended_video_ids[0], :creator => @user)
        @viewed_roll.frames << @viewed_frame

        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_video_ids.length - 1
        result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_video_ids[1], :src_frame_id => @src_frame_ids[1]})
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

      dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
    end

    context "no recommendations yet within the recent limit number of frames" do

      it "should return a new dashboard entry with a video graph recommendation if any are available" do
        result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        result.should be_an_instance_of(DashboardEntry)
        result.src_frame.should == @f
        result.video_id.should == @rec_vid.id
      end

      it "should persist a new dashboard entry to the database" do
        lambda {
          GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        }.should change { DashboardEntry.count }
      end

      it "should persist a new frame to the database" do
        lambda {
          GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        }.should change { Frame.count }
      end

      it "should not create a conversation because no message is being passed" do
        lambda {
          GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
        }.should change { Conversation.count }
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

      it "should not persist any new frames or dashboard entries to the database" do
        # put a recommendation in the dashboard
        GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)

        lambda {
          # check if we need to put another one
          GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
          # since there's already a recommendation in the last five (the one we just created), we shouldn't put another
        }.should_not change {"#{DashboardEntry.count},#{Frame.count}"}
      end
    end

  end

end
