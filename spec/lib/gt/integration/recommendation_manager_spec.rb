require 'spec_helper'
require 'recommendation_manager'

# INTEGRATION test
describe GT::RecommendationManager do
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

  context "get_random_video_graph_recs_for_user" do

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

end
