require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do
  before(:each) do
    @user = Factory.create(:user)

    @frame_ids = []
    @video_ids = []
    50.times do |i|
      v = Factory.create(:video)
      @video_ids << v.id
      f = Factory.create(:frame, :video => v, :creator => @user )
      @frame_ids << f.id
      dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id)
      @user.dashboard_entries << dbe
    end
  end

  context "get_random_video_graph_recs_for_user" do

    before(:each) do
      dbe_query = double("dbe_query")
      dbe_query.stub_chain(:limit, :fields, :map).and_return(@frame_ids)
      DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(dbe_query)

      frame_query = double("frame_query")
      frame_query.stub_chain(:fields, :map).and_return(@video_ids)
      Frame.should_receive(:where).with(:id => {:$in => @frame_ids}).and_return(frame_query)

      video_query = double("video_query")
    end

    it "should do all necessary database queries to get the videos in the users dashboard" do
      GT::RecommendationManager.get_random_video_graph_recs_for_user(@user)
    end

  end

end
