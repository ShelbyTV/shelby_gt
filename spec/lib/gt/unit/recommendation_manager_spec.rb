require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do
  before(:each) do
    GT::VideoManager.stub(:update_video_info)
  end

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

      @available_vid = Factory.create(:video)
      Video.stub(:find).and_return(@available_vid)
    end

    context "no prefetched dbes" do
      before(:each) do
        dbe_query = double("dbe_query")
        dbe_query.stub_chain(:order, :limit, :fields, :all).and_return(@dbes)
        DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(dbe_query)

        @video_ids.each_with_index do |id, j|
          video_query = double("video_query")
          video_query.stub_chain(:fields, :map, :flatten).and_return(@recs_per_video[j])
          Video.stub(:where).with(:id => id).and_return(video_query)
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

        it "should exclude videos that are no longer available at the provider" do
          @available_vid = Factory.create(:video)
          @unavailable_vid = Factory.create(:video, :available => false)
          Video.should_receive(:find).exactly(@recommended_video_ids.length).times.and_return(@unavailable_vid, @available_vid)
          GT::VideoManager.should_receive(:update_video_info).exactly(@recommended_video_ids.length).times

          result = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, nil)
          result.length.should == @recommended_video_ids.length - 1
          result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        end

        it "shoud exclude from consideration dashboard entries that are recommendations themselves" do
          @dbes[1].action = DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]

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

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user, {:num_recents_to_check => 1})
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

      GT::RecommendationManager.should_receive(:create_recommendation_dbentry).with(
        @user,
        rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        { :src_id => f.id}
      ).and_call_original

      result = GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
      result.should be_an_instance_of(DashboardEntry)
      result.src_frame.should == f
      result.video_id.should == rec_vid.id
      result.action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
    end
  end

  context "create_recommendation_dbentry" do
    before(:each) do
      @user = Factory.create(:user)
      @rec_vid = Factory.create(:video)
    end

    it "should return nil if the Framer fails" do
      GT::Framer.stub(:create_frame)

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
      ).should be_nil
    end

    it "should re-format the Framer result to return the correct format of data" do
      new_dbe = Factory.create(:dashboard_entry)
      new_frame = Factory.create(:frame)
      GT::Framer.stub(:create_frame).and_return({:dashboard_entries => [new_dbe], :frame => new_frame})

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
      ).should == {:dashboard_entry => new_dbe, :frame => new_frame}
    end

    it "should create a db entry for a video graph recommendation with the corresponding video, action, and src_frame" do
      src_frame = Factory.create(:frame)
      GT::Framer.should_receive(:create_frame).with({
        :video_id => @rec_vid.id,
        :dashboard_user_id => @user.id,
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :persist => true,
        :dashboard_entry_options => {
          :src_frame_id => src_frame.id
        }
      })

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        {
          :src_id => src_frame.id
        }
      )
    end

    it "should pass through the persist option to the framer" do
      src_frame = Factory.create(:frame)
      GT::Framer.should_receive(:create_frame).with({
        :video_id => @rec_vid.id,
        :dashboard_user_id => @user.id,
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :persist => false,
        :dashboard_entry_options => {
          :src_frame_id => src_frame.id
        }
      })

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        {
          :src_id => src_frame.id,
          :persist => false
        }
      )
    end

    it "should create a db entry for a mortar recommendation with the corresponding video, action, and src_video" do
      src_video = Factory.create(:video)
      GT::Framer.should_receive(:create_frame).with({
        :video_id => @rec_vid.id,
        :dashboard_user_id => @user.id,
        :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        :persist => true,
        :dashboard_entry_options => {
          :src_video_id => src_video.id
        }
      })

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        {
          :src_id => src_video.id
        }
      )
    end
  end

  context "get_mortar_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
    end

    it "should call MortarHarvester with the appropriate parameters" do
      GT::MortarHarvester.should_receive(:get_recs_for_user).with(@user, 50).twice
      Frame.should_not_receive(:where)

      GT::RecommendationManager.get_mortar_recs_for_user(@user)
      GT::RecommendationManager.get_mortar_recs_for_user(@user, 20)
    end

    it "should return an empty array if the request to Mortar fails" do
      GT::MortarHarvester.stub(:get_recs_for_user).and_return(nil)
      Frame.should_not_receive(:where)

      GT::RecommendationManager.get_mortar_recs_for_user(@user).should == []
    end

    context "recommendations found and returned" do
      before(:each) do
        @recommended_video = Factory.create(:video)
        @reason_video = Factory.create(:video)
        @recommended_video2 = Factory.create(:video)
        @reason_video2 = Factory.create(:video)
        @recommended_video3 = Factory.create(:video)
        @reason_video3 = Factory.create(:video)
        Video.stub(:find).and_return(@recommended_video, @recommended_video2, @recommended_video3)
        GT::MortarHarvester.stub(:get_recs_for_user).and_return([
          {"item_id" => @recommended_video.id.to_s, "reason_id" => @reason_video.id.to_s},
          {"item_id" => @recommended_video2.id.to_s, "reason_id" => @reason_video2.id.to_s},
          {"item_id" => @recommended_video3.id.to_s, "reason_id" => @reason_video3.id.to_s},
        ])

        @frame_query = double("frame_query")
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([])
        # only needs to load the user's viewed videos once
        Frame.should_receive(:where).with(:roll_id => @viewed_roll.id).exactly(1).times.and_return(@frame_query)
      end


      it "should map the key names correctly" do
        GT::RecommendationManager.get_mortar_recs_for_user(@user).should ==
          [{
            :recommended_video_id => @recommended_video.id,
            :src_id => @reason_video.id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end

      it "should skip videos whose ids are not in the Shelby DB" do
        Video.should_receive(:find).twice().and_return(nil, @recommended_video2)
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_video2).once()
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_video)

        GT::RecommendationManager.get_mortar_recs_for_user(@user).should ==
          [{
            :recommended_video_id => @recommended_video2.id,
            :src_id => @reason_video2.id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end

      it "should skip videos the user has already watched" do
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([@recommended_video.id.to_s])
        Video.should_receive(:find).once().and_return(@recommended_video2)
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_video2).once()
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_video)

        GT::RecommendationManager.get_mortar_recs_for_user(@user).should ==
          [{
            :recommended_video_id => @recommended_video2.id,
            :src_id => @reason_video2.id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end

      it "should still only load the viewed videos once when multiple recommended videos are processed" do
        Video.should_receive(:find).twice().and_return(@recommended_video, @recommended_video2)

        GT::RecommendationManager.get_mortar_recs_for_user(@user,2).length.should == 2
      end

      it "should skip videos that are known to be no longer available at the provider" do
        @recommended_video.available = false
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_video2).once()
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_video)
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_video3)

        GT::RecommendationManager.get_mortar_recs_for_user(@user).should ==
          [{
            :recommended_video_id => @recommended_video2.id,
            :src_id => @reason_video2.id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end

      it "should skip videos that are no longer available at the provider after re-checking" do
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_video) {
          @recommended_video.available = false
          nil
        }
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_video2).once()
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_video3)

        GT::RecommendationManager.get_mortar_recs_for_user(@user).should ==
          [{
            :recommended_video_id => @recommended_video2.id,
            :src_id => @reason_video2.id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end


    end



  end

end
