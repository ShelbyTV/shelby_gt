require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do
  before(:each) do
    @viewed_roll = Factory.create(:roll)
    @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

    @video_ids = []
    @recs_per_video = []
    @recommendations = []
    @recommended_video_ids = []
    @src_frame_ids = []
    @dbes = []
    # create dashboard entries 0 to n, entry i will have i recommendations attached to its video
    4.times do |i|
      v = Factory.create(:video)
      recs_for_this_video = []
      @video_ids << v.id

      f = Factory.create(:frame, :video => v, :creator => @user )

      i.times do |j|
        rec_vid = Factory.create(:video)
        rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
        v.recs << rec
        recs_for_this_video << rec
        @recommendations << rec
        @recommended_video_ids << rec_vid.id
        @src_frame_ids << f.id
      end

      @recs_per_video << recs_for_this_video

      dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
      @dbes << dbe
    end
  end

  context "get_random_video_graph_recs_for_user" do

    before(:each) do
      dbe_query = double("dbe_query")
      dbe_query.stub_chain(:order, :limit, :fields, :all).and_return(@dbes)
      DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(dbe_query)

      @video_ids.each_with_index do |id, i|
        video_query = double("video_query")
        video_query.stub_chain(:fields, :map, :flatten).and_return(@recs_per_video[i])
        Video.should_receive(:where).with(:id => id).and_return(video_query)
      end

      # don't actually do any shuffling so we can predict and compare results
      Array.any_instance.should_receive(:shuffle!)
    end

    context "when some recommendations are found" do

      before (:each) do
        @frame_query = double("frame_query")
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([])
        # only needs to load the user's viewed videos once
        Frame.should_receive(:where).with(:roll_id => @viewed_roll.id).exactly(1).times.and_return(@frame_query)
      end

      it "should return all the recommended videos when there is no limit parameter" do
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil)
        result.length.should == @recommended_video_ids.length
        result.should == @recommended_video_ids.each_with_index.map{|id, i| {:recommended_video_id => id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude videos the user has already watched" do
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([@recommended_video_ids[0]])

        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil)
        result.length.should == @recommended_video_ids.length - 1
        result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
      end

      it "should return only one recommended video id by default" do
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user)
        result.should be_an_instance_of(Array)
        result.should == [{:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]}]
      end

      it "should restrict the results to recommended videos that meet the minimum score parameter" do
        max_score = @recommendations.max_by{|r| r.score}.score
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil, max_score)
        result.should == [{:recommended_video_id => @recommended_video_ids.last, :src_frame_id => @src_frame_ids.last}]
      end

    end

    context "when no recommendations are found" do

      it "should not load the user's viewed videos to check against" do
        Frame.should_not_receive(:where)

        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 1, 1, 1000.0)
      end

    end

  end

end
