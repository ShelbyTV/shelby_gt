require 'spec_helper'
require 'recommendation_manager'

# INTEGRATION test
describe GT::RecommendationManager do
  before(:each) do
    @viewed_roll = Factory.create(:roll)
    @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

    @recommended_video_ids = []
    # create dashboard entries 0 to n, entry i will have i recommendations attached to its video
    4.times do |i|
      v = Factory.create(:video)

      i.times do |j|
        rec_vid = Factory.create(:video)
        rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
        v.recs << rec
        @recommended_video_ids << rec_vid.id
      end

      v.save

      f = Factory.create(:frame, :video => v, :creator => @user )

      dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
    end
  end

  context "get_random_video_graph_recs_for_user" do

    it "should return all of the recommendations when there are no restricting limits" do
      MongoMapper::Plugins::IdentityMap.clear
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
      (result - @recommended_video_ids).should == []
    end

    context "stub shuffle! so we can test everything else more carefully " do

      before(:each) do
        Array.any_instance.stub(:shuffle!)
      end

      it "should return all of the recommendations when there are no restricting limits" do
        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.should == @recommended_video_ids
      end

      it "should exclude videos the user has already watched" do
        @viewed_frame = Factory.create(:frame, :video_id => @recommended_video_ids[0], :creator => @user)
        @viewed_roll.frames << @viewed_frame

        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 10)
        result.length.should == @recommended_video_ids.length - 1
        result.should_not include(@recommended_video_ids[0])
      end

      it "should return only one recommended video by default" do
        MongoMapper::Plugins::IdentityMap.clear
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user)
        result.should == [@recommended_video_ids[0]]
      end

    end

  end

end
