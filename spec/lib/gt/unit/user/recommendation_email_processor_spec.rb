# encoding: UTF-8

require 'spec_helper'

require 'recommendation_email_processor'

# UNIT test
describe GT::RecommendationEmailProcessor do

  before(:each) do
    @user = Factory.create(:user)
    @user.viewed_roll = Factory.create(:roll, :creator => @user)
    GT::VideoProviderApi.stub(:get_video_info)
  end

  describe "get_recommendations_for_user" do

    before(:each) do
      @rmDouble = double("rm")
      GT::RecommendationManager.should_receive(:new).with(@user).and_return(@rmDouble)
      Array.any_instance.should_receive(:shuffle!)
    end

    it "gets some recommendations for the user" do

      @rmDouble.should_receive(:get_recs_for_user).with({
        :limits => [1,1,1],
        :sources => [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:channel_recommendation],  DashboardEntry::ENTRY_TYPE[:mortar_recommendation]],
        :video_graph_entries_to_scan => 60
      }).and_return([])
      @rmDouble.should_not_receive(:create_recommendation_dbentry)

      GT::RecommendationEmailProcessor.get_recommendations_for_user(@user).should == []
    end

    it "creates persisted dbentries for the recommendations" do
      video = Factory.create(:video)
      src_frame = Factory.create(:frame)
      @rmDouble.stub(:get_recs_for_user).and_return([{
        :recommended_video_id => video.id,
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :src_id => src_frame.id
      }])
      GT::RecommendationManager.should_receive(:create_recommendation_dbentry).with(
        @user,
        video.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        {:src_id => src_frame.id}
      )

      GT::RecommendationEmailProcessor.get_recommendations_for_user(@user).should == []
    end

    it "sends a recommendation email to the user" do
      video = Factory.create(:video)
      src_frame = Factory.create(:frame)
      dbe = Factory.create(:dashboard_entry)
      @rmDouble.stub(:get_recs_for_user).and_return([{
        :recommended_video_id => video.id,
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :src_id => src_frame.id
      }])
      GT::RecommendationManager.stub(:create_recommendation_dbentry).and_return({:dashboard_entry => dbe})

      GT::RecommendationEmailProcessor.get_recommendations_for_user(@user).should == [dbe]
    end

  end

end
