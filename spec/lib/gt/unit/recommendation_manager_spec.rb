require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do
  before(:each) do
    @user = Factory.create(:user)

    @frame_ids = []
    @video_ids = []
    @videos = []
    @recommendations = []
    @recommended_video_ids = []
    # create dashboard entries 0 to n, entry i will have i recommendations attached to its video
    4.times do |i|
      v = Factory.create(:video)
      @video_ids << v.id
      @videos << v

      i.times do |j|
        rec_vid = Factory.create(:video)
        rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
        v.recs << rec
        @recommendations << rec
        @recommended_video_ids << rec_vid.id
      end

      f = Factory.create(:frame, :video => v, :creator => @user )
      @frame_ids << f.id

      dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
    end
  end

  context "get_random_video_graph_recs_for_user" do

    before(:each) do
      dbe_query = double("dbe_query")
      dbe_query.stub_chain(:order, :limit, :fields, :map).and_return(@video_ids)
      DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(dbe_query)

      video_query = double("video_query")
      video_query.stub_chain(:fields, :map, :flatten).and_return(@recommendations)
      Video.should_receive(:where).with(:id => {:$in => @video_ids}).and_return(video_query)

      @recommendations.should_receive(:shuffle!)
    end

    it "should return all the recommended videos when there is no limit parameter" do
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil)
      result.length.should == @recommended_video_ids.length
      result.should == @recommended_video_ids
    end

    it "should return only one recommended video id by default" do
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user)
      result.should be_an_instance_of(Array)
      result.should == [@recommended_video_ids[0]]
    end

    it "should restrict the results to recommended videos that meet the minimum score parameter" do
      max_score = @recommendations.max_by{|r| r.score}.score
      result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil, max_score)
      result.should == [@recommended_video_ids.last]
    end

  end

end
