require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do

  context "get_random_video_graph_recs_for_user" do
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

      # don't actually do any shuffling so we can predict and compare results
      Array.any_instance.should_receive(:shuffle!)
    end

    context "no prefetched dbes" do
      before(:each) do
        dbe_query = double("dbe_query")
        dbe_query.stub_chain(:order, :limit, :fields, :all).and_return(@dbes)
        DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(dbe_query)

        @video_ids.each_with_index do |id, j|
          video_query = double("video_query")
          video_query.stub_chain(:fields, :map, :flatten).and_return(@recs_per_video[j])
          Video.should_receive(:where).with(:id => id).and_return(video_query)
        end
      end

      context "when some recommendations are found" do
        before(:each) do
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

    context "when prefetched_dbes are passed in" do
      it "should not fetch any dbes" do
        DashboardEntry.should_not_receive(:where)

        GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 1, 100.0, [])
      end

      it "should use the prefetched_dbes the same way it would if it looked them up itself" do
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, 1, nil, @dbes)
        result.should be_an_instance_of(Array)
        result.should == [{:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]}]
      end

      it "should only look at as many prefetched_dbes as we tell it to with max_db_entries_to_scan parameter" do
        result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 0, 1, nil, @dbes)
        result.should be_an_instance_of(Array)
        result.should be_empty
      end
    end


  end

  context "if_no_recent_recs_generate_recs" do
    before(:each) do
      @user = Factory.create(:user)
    end

    it "should not generate recs if there are recommendations within num_recents_to_check dbes" do
      dbe = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return([dbe])
      GT::RecommendationManager.should_not_receive(:get_random_video_graph_recs_for_user)

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
    end

    it "should generate recs if there are no recommendations within num_recents_to_check dbes" do
      dbe = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      dbes = [dbe]
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return(dbes)
      GT::RecommendationManager.should_receive(:get_random_video_graph_recs_for_user).with(@user, 10, 1, 100.0, dbes).and_return([])

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
    end

    it "should limit the search for recent recs according to the num_recents_to_check_parameter" do
      dbe_social = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      dbe_rec = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
      dbes = [dbe_social, dbe_rec]
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return(dbes)
      GT::RecommendationManager.should_receive(:get_random_video_graph_recs_for_user).with(@user, 10, 1, 100.0, dbes).and_return([])

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user, 1)
    end

    it "should return nil if no video graph recommendations are available within the given search parameters" do
      dbe = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return([dbe])
      GT::RecommendationManager.stub(:get_random_video_graph_recs_for_user).and_return([])

      result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
      result.should be_nil
    end

    it "should return a new dashboard entry with a video graph recommendation if any are available" do
      v = Factory.create(:video)
      rec_vid = Factory.create(:video)
      rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id, :score => 100.0)
      v.recs << rec

      f = Factory.create(:frame, :video => v, :creator => @user )

      dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])

      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return([dbe])
      GT::RecommendationManager.stub(:get_random_video_graph_recs_for_user).and_return(
        [{:recommended_video_id => rec_vid.id, :src_frame_id => f.id}]
      )

      result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
      result.should be_an_instance_of(DashboardEntry)
      result.src_frame.should == f
      result.video_id.should == rec_vid.id
    end
  end

end
