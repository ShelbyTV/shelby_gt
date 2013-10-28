require 'spec_helper'
require 'recommendation_manager'

# UNIT test
describe GT::RecommendationManager do
  before(:each) do
    GT::VideoProviderApi.stub(:get_video_info)
  end

  context "constructor" do

    before(:each) do
      @user = Factory.create(:user)
    end

    context "arguments" do
      it "requires a user" do
        expect { GT::RecommendationManager.new }.to raise_error(ArgumentError)
        expect { GT::RecommendationManager.new("fred") }.to raise_error(ArgumentError, "must supply valid User Object")
        expect { GT::RecommendationManager.new(@user) }.not_to raise_error
      end
    end

    it "should initialize instance variables" do
      u = GT::RecommendationManager.new(@user)
      u.instance_variable_get(:@user).should == @user
      u.instance_variable_get(:@watched_videos_loaded).should == false
      u.instance_variable_get(:@watched_video_ids).should be_nil
      u.instance_variable_get(:@exclude_missing_thumbnails).should == true
      u.instance_variable_get(:@recommended_sharer_ids).should == []

      u = GT::RecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
      u.instance_variable_get(:@exclude_missing_thumbnails).should == false
    end
  end

  context "get_video_graph_recs_for_user" do
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

        sharer = Factory.create(:user)
        f = Factory.create(:frame, :video => v, :creator => sharer )

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

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :actor => sharer)
        @dbes << dbe
      end

      # don't actually do any shuffling so we can predict and compare results
      Array.any_instance.stub(:shuffle!)

      @available_vid = Factory.create(:video)
      Video.stub(:find).and_return(@available_vid)

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    context "no prefetched dbes" do
      before(:each) do
        @dbe_query = double("dbe_query")
        @dbe_query.stub_chain(:order, :limit, :fields, :all).and_return(@dbes)
        DashboardEntry.stub(:where).with(:user_id => @user.id).and_return(@dbe_query)

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
          Frame.stub(:where).with(:roll_id => @viewed_roll.id).and_return(@frame_query)
        end

        it "should return all the recommended videos when there is no limit parameter" do
          Array.any_instance.should_receive(:shuffle!)
          DashboardEntry.should_receive(:where).with(:user_id => @user.id).and_return(@dbe_query)
          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length
          result.should == @recommended_video_ids.each_with_index.map{|id, i| {:recommended_video_id => id, :src_frame_id => @src_frame_ids[i]}}
        end

        it "limits to the proper number of results when there is a limit parameter" do
          @recommendation_manager.get_video_graph_recs_for_user(10, 2).length.should == 2
        end

        it "should exclude videos the user has already watched" do
          @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([@recommended_video_ids[0]])

          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length - 1
          result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        end

        it "looks up the user's viewed frames only once, caching the results for future invocations" do
          Frame.should_receive(:where).with(:roll_id => @viewed_roll.id).exactly(1).times.and_return(@frame_query)

          @recommendation_manager.instance_variable_get(:@watched_video_ids).should be_nil
          @recommendation_manager.instance_variable_get(:@watched_videos_loaded).should == false
          @recommendation_manager.get_video_graph_recs_for_user(10, nil)
          @recommendation_manager.instance_variable_get(:@watched_video_ids).should == []
          @recommendation_manager.instance_variable_get(:@watched_videos_loaded).should == true
          @recommendation_manager.get_video_graph_recs_for_user(10, nil)
        end

        it "should exclude videos that are no longer available at the provider" do
          @available_vid = Factory.create(:video)
          @unavailable_vid = Factory.create(:video, :available => false)
          Video.should_receive(:find).exactly(@recommended_video_ids.length).times.and_return(@unavailable_vid, @available_vid)
          GT::VideoManager.should_receive(:update_video_info).exactly(@recommended_video_ids.length).times

          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length - 1
          result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        end

        it "should exclude videos that are missing their thumbnails when that option is set" do
          @vid_with_thumbnail = Factory.create(:video)
          @vid_without_thumbnail = Factory.create(:video, :thumbnail_url => nil)

          Video.should_receive(:find).exactly(@recommended_video_ids.length).times.and_return(@vid_without_thumbnail, @vid_with_thumbnail)

          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length - 1
          result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        end

        it "should not exclude videos that are missing their thumbnails when that option is not set" do
          @vid_with_thumbnail = Factory.create(:video)
          @vid_without_thumbnail = Factory.create(:video, :thumbnail_url => nil)

          Video.should_receive(:find).exactly(@recommended_video_ids.length).times.and_return(@vid_without_thumbnail, @vid_with_thumbnail)

          rm = GT::RecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
          result = rm.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length
          result.should == @recommended_video_ids.each_with_index.map{|id, i| {:recommended_video_id => id, :src_frame_id => @src_frame_ids[i]}}
        end

        it "should exclude from consideration dashboard entries that have no actor" do
          @dbes[1].actor_id = nil

          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, nil, nil, {:unique_sharers_only => false})
          result.length.should == @recommended_video_ids.length - 1
          result.should_not include({:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]})
        end

        it "should return only one recommended video id by default" do
          result = @recommendation_manager.get_video_graph_recs_for_user
          result.should be_an_instance_of(Array)
          result.should == [{:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]}]
        end

        it "should restrict the results to recommended videos that meet the minimum score parameter" do
          max_score = @recommendations.max_by{|r| r.score}.score
          result = @recommendation_manager.get_video_graph_recs_for_user(10, nil, max_score)
          result.should == [{:recommended_video_id => @recommended_video_ids.last, :src_frame_id => @src_frame_ids.last}]
        end

      end

      context "when no recommendations are found" do

        it "should not load the user's viewed videos to check against" do
          Frame.should_not_receive(:where)

          result = @recommendation_manager.get_video_graph_recs_for_user(1, 1, 1000.0)
        end

      end

    end

    context "when prefetched_dbes are passed in" do
      it "should not fetch any dbes" do
        DashboardEntry.should_not_receive(:where)

        @recommendation_manager.get_video_graph_recs_for_user(10, 1, 100.0, [])
      end

      it "should use the prefetched_dbes the same way it would if it looked them up itself" do
        Array.any_instance.should_receive(:shuffle!)
        result = @recommendation_manager.get_video_graph_recs_for_user(10, 1, nil, @dbes)
        result.should be_an_instance_of(Array)
        result.should == [{:recommended_video_id => @recommended_video_ids[0], :src_frame_id => @src_frame_ids[0]}]
      end

      it "should only look at as many prefetched_dbes as we tell it to with max_db_entries_to_scan parameter" do
        result = @recommendation_manager.get_video_graph_recs_for_user(0, 1, nil, @dbes)
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
      GT::RecommendationManager.any_instance.should_not_receive(:get_video_graph_recs_for_user)

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
    end

    it "should generate recs if there are no recommendations within num_recents_to_check dbes" do
      dbe = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      dbes = [dbe]
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return(dbes)
      GT::RecommendationManager.any_instance.should_receive(:get_video_graph_recs_for_user).with(Settings::Recommendations.video_graph[:entries_to_scan], 1, Settings::Recommendations.video_graph[:min_score], dbes).and_return([])

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user)
    end

    it "limits the search for recent recs according to the num_recents_to_check_parameter when it's greater than num_entries_to_scan" do
      Settings::Recommendations.video_graph[:entries_to_scan] = 1

      dbe_social = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      dbe_rec = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
      dbes = [dbe_social, dbe_rec]

      @limit_query = double("limit_query")
      @limit_query.stub_chain(:fields, :all).and_return(dbes)

      @order_query = double("order_query")
      @order_query.should_receive(:limit).with(3).and_return(@limit_query)
      DashboardEntry.stub_chain(:where, :order).and_return(@order_query)

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user, {:num_recents_to_check => 3})
    end

    it "limits the search for recent recs according to the num_rentries_to_scan when it's greater than num_recents_to_check_parameter" do
      Settings::Recommendations.video_graph[:entries_to_scan] = 5

      dbe_social = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      dbe_rec = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
      dbes = [dbe_social, dbe_rec]

      @limit_query = double("limit_query")
      @limit_query.stub_chain(:fields, :all).and_return(dbes)

      @order_query = double("order_query")
      @order_query.should_receive(:limit).with(5).and_return(@limit_query)
      DashboardEntry.stub_chain(:where, :order).and_return(@order_query)

      GT::RecommendationManager.if_no_recent_recs_generate_rec(@user, {:num_recents_to_check => 2})
    end

    it "should return nil if no video graph recommendations are available within the given search parameters" do
      dbe = Factory.create(:dashboard_entry, :user => @user, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame])
      DashboardEntry.stub_chain(:where, :order, :limit, :fields, :all).and_return([dbe])
      GT::RecommendationManager.any_instance.stub(:get_video_graph_recs_for_user).and_return([])

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
      GT::RecommendationManager.any_instance.stub(:get_video_graph_recs_for_user).and_return(
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

    it "should return nil if the Framer fails to create a frame" do
      GT::Framer.stub(:create_frame)

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
      ).should be_nil
    end

    it "should return nil if the Framer fails to create a dashboard entry" do
      src_frame = Factory.create(:frame)
      GT::Framer.stub(:create_dashboard_entry)

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        {
          :src_id => src_frame.id,
          :persist => false
        }
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

    it "should create a db entry for a channel recommendation with the corresponding frame, video, and action" do
      src_frame = Factory.create(:frame)
      Frame.stub(:find).and_return(src_frame)

      new_dbe = Factory.create(:dashboard_entry, :frame => src_frame)
      GT::Framer.should_receive(:create_dashboard_entry).with(src_frame, DashboardEntry::ENTRY_TYPE[:channel_recommendation], @user, {}, false).and_return([new_dbe])

      GT::Framer.should_not_receive(:create_frame)

      GT::RecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        {
          :src_id => src_frame.id,
          :persist => false
        }
      ).should == {:dashboard_entry => new_dbe, :frame => src_frame}
    end

  end

  context "get_channel_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
      @channel_user = Factory.create(:user)

      @recommendation_manager = GT::RecommendationManager.new(@user)
      @recommendation_manager.stub(:filter_recs).and_return([])
    end

    context "arguments" do

      it "requires a channel user id" do
        expect { @recommendation_manager.get_channel_recs_for_user(nil) }.to raise_error(ArgumentError, "must supply a valid channel user id")
        expect { @recommendation_manager.get_channel_recs_for_user("123") }.to raise_error(ArgumentError, "must supply a valid channel user id")

        expect { @recommendation_manager.get_channel_recs_for_user(@channel_user.id) }.to_not raise_error
        expect { @recommendation_manager.get_channel_recs_for_user(@channel_user.id.to_s) }.to_not raise_error
      end

      it "requires a limit greater than zero" do
        expect { @recommendation_manager.get_channel_recs_for_user(@channel_user.id, nil) }.to raise_error(ArgumentError, "must supply a limit > 0")
        expect { @recommendation_manager.get_channel_recs_for_user(@channel_user.id, 0) }.to raise_error(ArgumentError, "must supply a limit > 0")
        expect { @recommendation_manager.get_channel_recs_for_user(@channel_user.id, -1) }.to raise_error(ArgumentError, "must supply a limit > 0")
      end
    end

    it "should fetch dbes from the specified user channel" do
      dbe_query = double("dbe_query")
      dbe_query.stub_chain(:order, :limit, :fields, :all, :shuffle!).and_return([])
      DashboardEntry.should_receive(:where).with(:user_id => @channel_user.id).and_return(dbe_query)

      @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should == []
    end

    context "recommendations found and returned" do
      before(:each) do
        @dbes = []
        @videos = []
        @frames = []
        3.times do
          video = Factory.create(:video)
          @videos << video
          sharer = Factory.create(:user)
          frame = Factory.create(:frame, :video_id => video.id, :creator_id => sharer.id)
          @frames << frame
          @dbes << Factory.create(:dashboard_entry, :user_id => @channel_user.id, :frame_id => frame.id, :video_id => video.id, :actor_id => sharer.id)
        end

        @dbes.stub(:all).and_return(@dbes)
        @dbes.stub(:shuffle!).and_return(@dbes)

        dbe_query = double("dbe_query")
        dbe_query.stub_chain(:order, :limit, :fields).and_return(@dbes)
        DashboardEntry.stub(:where).with(:user_id => @channel_user.id).and_return(dbe_query)
      end

      it "should map the key names correctly" do
        @recommendation_manager.should_receive(:filter_recs).and_return([@dbes[0]])
        @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
          [{
            :recommended_video_id => @videos[0].id,
            :src_id => @frames[0].id,
            :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
          }]
      end

      it "shuffles the recommendations before filtering them, by default" do
        @dbes.should_receive(:all)
        @dbes.should_receive(:shuffle!)

        @recommendation_manager.get_channel_recs_for_user(@channel_user.id)
      end

      it "does not shuffle the recommendations if that option is not set" do
        @dbes.should_not_receive(:all)
        @dbes.should_not_receive(:shuffle!)

        @recommendation_manager.get_channel_recs_for_user(@channel_user.id, 1, {:shuffle => false})
      end

      it "filters the recs" do
        @recommendation_manager.should_receive(:filter_recs).with(
          @dbes,
          {:limit => 1, :recommended_video_key => "video_id"}
        ).ordered.and_yield(@dbes[0]).and_return([])

        @recommendation_manager.should_receive(:filter_recs).with(
          @dbes,
          {:limit => 2, :recommended_video_key => "video_id"}
        ).ordered.and_yield(@dbes[0]).and_yield(@dbes[1]).and_return([])

        @recommendation_manager.get_channel_recs_for_user(@channel_user.id).should == []
        @recommendation_manager.get_channel_recs_for_user(@channel_user.id, 2).should == []
      end

    end

  end

  context "get_mortar_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
      @recommendation_manager = GT::RecommendationManager.new(@user)
      @recommendation_manager.stub(:filter_recs).and_return([])
    end

    context "arguments" do
      it "requires a limit greater than zero" do
        expect { @recommendation_manager.get_mortar_recs_for_user(nil) }.to raise_error(ArgumentError, "must supply a limit > 0")
        expect { @recommendation_manager.get_mortar_recs_for_user(0) }.to raise_error(ArgumentError, "must supply a limit > 0")
        expect { @recommendation_manager.get_mortar_recs_for_user(-1) }.to raise_error(ArgumentError, "must supply a limit > 0")
      end
    end

    it "should call MortarHarvester with the appropriate parameters" do
      GT::MortarHarvester.should_receive(:get_recs_for_user).with(@user, 50).ordered
      GT::MortarHarvester.should_receive(:get_recs_for_user).with(@user, 20 + 49).ordered

      @recommendation_manager.get_mortar_recs_for_user
      @recommendation_manager.get_mortar_recs_for_user(20)
    end

    it "should return an empty array if the request to Mortar doesn't return any recs" do
      GT::MortarHarvester.stub(:get_recs_for_user).and_return(nil)
      @recommendation_manager.should_not_receive(:filter_recs)

      @recommendation_manager.get_mortar_recs_for_user.should == []
    end

    it "should return an empty array if the request to Mortar fails" do
      GT::MortarHarvester.stub(:get_recs_for_user).and_return([])
      @recommendation_manager.should_not_receive(:filter_recs)

      @recommendation_manager.get_mortar_recs_for_user.should == []
    end

    context "recommendations found and returned" do
      before(:each) do
        @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
        @reason_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]

        @mortar_recs = [
          {"item_id" => @recommended_videos[0].id.to_s, "reason_id" => @reason_videos[0].id.to_s},
          {"item_id" => @recommended_videos[1].id.to_s, "reason_id" => @reason_videos[1].id.to_s},
          {"item_id" => @recommended_videos[2].id.to_s, "reason_id" => @reason_videos[2].id.to_s},
        ]
        GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_recs)
      end

      it "shuffles the recommendations before filtering them, by default" do
        @mortar_recs.should_receive(:shuffle!)

        @recommendation_manager.get_mortar_recs_for_user
      end

      it "does not shuffle the recommendations if that option is not set" do
        @mortar_recs.should_not_receive(:shuffle!)

        @recommendation_manager.get_mortar_recs_for_user(1, {:shuffle => false})
      end

      it "should map the key names correctly" do
        @recommendation_manager.should_receive(:filter_recs).and_return([@mortar_recs[0]])
        @recommendation_manager.get_mortar_recs_for_user.should ==
          [{
            :recommended_video_id => @recommended_videos[0].id,
            :src_id => @reason_videos[0].id,
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }]
      end

      it "should filter the recs" do
        @recommendation_manager.should_receive(:filter_recs).with(
          @mortar_recs,
          {:limit => 1, :recommended_video_key => "item_id"}
        ).ordered.and_return([])

        @recommendation_manager.should_receive(:filter_recs).with(
          @mortar_recs,
          {:limit => 2, :recommended_video_key => "item_id"}
        ).ordered.and_return([])

        @recommendation_manager.get_mortar_recs_for_user.should == []
        @recommendation_manager.get_mortar_recs_for_user(2).should == []
      end

    end

  end

  context "get_recs_for_user" do
      before(:each) do
        @user = Factory.create(:user)
        @featured_channel_user = Factory.create(:user)
        Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
        @recommendation_manager = GT::RecommendationManager.new(@user)
      end

      it "should map and return results correctly" do
        video_graph_rec = { :src_frame_id => "someid", :importantstuff => "ishere"}
        mortar_rec = { :something => 'somethingelse'}
        channel_rec = { :somethingdifferent => 'moredate'}

        @recommendation_manager.stub(:get_video_graph_recs_for_user).and_return([video_graph_rec])
        @recommendation_manager.stub(:get_mortar_recs_for_user).and_return([mortar_rec])
        @recommendation_manager.stub(:get_channel_recs_for_user).and_return([channel_rec])

        @recommendation_manager.get_recs_for_user({ :sources => [31, 33, 34], :limits => [1, 1, 1] }).should == [
          {
            :src_id => "someid",
            :importantstuff => "ishere",
            :action =>  DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
          },
          mortar_rec,
          channel_rec
        ]
      end

      it "raises an error if the sources and limits options arrays are not the same length" do
        expect {
          @recommendation_manager.get_recs_for_user({ :sources => [], :limits => [1,2] })
        }.to raise_error(ArgumentError, ":sources and :limits options must be Arrays of the same length")

        expect {
          @recommendation_manager.get_recs_for_user({ :sources => 1, :limits => 2 })
        }.to raise_error(ArgumentError, ":sources and :limits options must be Arrays of the same length")
      end

      it "uses video graph and mortar as sources by default" do
        @recommendation_manager.should_receive(:get_video_graph_recs_for_user).ordered.and_return([])
        @recommendation_manager.should_receive(:get_mortar_recs_for_user).ordered.and_return([])
        @recommendation_manager.should_not_receive(:get_channel_recs_for_user)

        @recommendation_manager.get_recs_for_user.should == []
      end

      it "calls methods to get the right kinds of recommendations based on the options" do
        @recommendation_manager.should_receive(:get_channel_recs_for_user).ordered.and_return([])
        @recommendation_manager.should_receive(:get_video_graph_recs_for_user).ordered.and_return([])
        @recommendation_manager.should_not_receive(:get_mortar_recs_for_user)

        @recommendation_manager.get_recs_for_user({ :sources => [34,31], :limits => [3, 3] })
      end

      it "calls the recommendation functions for each recommendation source with the right default parameters" do
        limits = [1,2,3]

        @recommendation_manager.should_receive(:get_video_graph_recs_for_user).with(
          Settings::Recommendations.video_graph[:entries_to_scan],
          limits[0],
          Settings::Recommendations.video_graph[:min_score]
        ).ordered().and_return(Array.new(limits[0]) { {} })
        @recommendation_manager.should_receive(:get_mortar_recs_for_user).with(limits[1]).ordered().and_return(Array.new(limits[1]) { {} })
        @recommendation_manager.should_receive(:get_channel_recs_for_user).with(@featured_channel_user.id.to_s, limits[2]).ordered().and_return(Array.new(limits[2]) { {} })

        @recommendation_manager.get_recs_for_user({ :sources => [31, 33, 34], :limits => limits }).length.should == 6
      end

      it "passes through the appropriate options to get_video_graph_recs_for_user" do
        @recommendation_manager.should_receive(:get_video_graph_recs_for_user).with(
          20,
          1,
          100.0
        ).ordered().and_return([ {} ])

        @recommendation_manager.get_recs_for_user({
          :sources => [31],
          :limits => [1],
          :video_graph_entries_to_scan => 20,
          :video_graph_min_score => 100.0
        }).length.should == 1
      end

      it "tries to fill in extras of the last type of recommendation if the earlier types don't find enough" do
        limits = [2,3]

        @recommendation_manager.should_receive(:get_mortar_recs_for_user).with(limits[0]).ordered().and_return([{}])
        @recommendation_manager.should_receive(:get_channel_recs_for_user).with(@featured_channel_user.id.to_s, 4).ordered().and_return(Array.new(4) { {} })

        @recommendation_manager.get_recs_for_user({ :sources => [33, 34], :limits => limits }).length.should == 5
      end

      it "doesn't fill in extras if {:fill_in_with_final_type => false} option is passed" do
        limits = [2,3]

        @recommendation_manager.should_receive(:get_mortar_recs_for_user).with(limits[0]).ordered().and_return([{}])
        @recommendation_manager.should_receive(:get_channel_recs_for_user).with(@featured_channel_user.id.to_s, 3).ordered().and_return(Array.new(3) { {} })

        @recommendation_manager.get_recs_for_user({ :sources => [33, 34], :limits => limits, :fill_in_with_final_type => false }).length.should == 4
      end

  end

  context "filter_recs" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      Frame.stub_chain(:where, :fields, :limit, :all).and_return([])

      @recommendation_manager = GT::RecommendationManager.new(@user)
    end

    context "arguments" do
      it "should require a limit greater than zero or nil" do
        expect { @recommendation_manager.send(:filter_recs, [], { :limit => 0 }) }.to raise_error(ArgumentError)
        expect { @recommendation_manager.send(:filter_recs, [], { :limit => -1 }) }.to raise_error(ArgumentError)

        expect { @recommendation_manager.send(:filter_recs, [], { :limit => 1 }) }.not_to raise_error
        expect { @recommendation_manager.send(:filter_recs, [], { :limit => nil }) }.not_to raise_error
        expect { @recommendation_manager.send(:filter_recs, []) }.not_to raise_error
      end
    end

    context "recommendations passed in" do
      before(:each) do
        @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
        @recommendations = @recommended_videos.map {|vid| { :recommended_video_id => vid.id.to_s }}

        @frame_query = double("frame_query")
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([])
        Frame.stub(:where).with(:roll_id => @viewed_roll.id).and_return(@frame_query)
      end

      it "should yield when a block is passed in" do
        expect { |b| @recommendation_manager.send(:filter_recs, @recommendations, &b) }.to yield_successive_args(@recommendations[0], @recommendations[1], @recommendations[2])
      end

      it "looks up the user's viewed frames only once, caching the results for future invocations" do
        Frame.should_receive(:where).exactly(1).times.and_return(@frame_query)

        @recommendation_manager.instance_variable_get(:@watched_video_ids).should be_nil
        @recommendation_manager.instance_variable_get(:@watched_videos_loaded).should == false
        @recommendation_manager.send(:filter_recs, @recommendations)
        @recommendation_manager.instance_variable_get(:@watched_video_ids).should == []
        @recommendation_manager.instance_variable_get(:@watched_videos_loaded).should == true
        @recommendation_manager.send(:filter_recs, @recommendations)
      end

      context "return all recs with id strings" do
        before(:each) do
          Video.should_receive(:find).with(@recommended_videos[0].id.to_s).ordered.and_return(@recommended_videos[0])
          Video.should_receive(:find).with(@recommended_videos[1].id.to_s).ordered.and_return(@recommended_videos[1])
          Video.should_receive(:find).with(@recommended_videos[2].id.to_s).ordered.and_return(@recommended_videos[2])
        end

        it "works without a limit" do
          @recommendation_manager.send(:filter_recs, @recommendations).should == @recommendations
        end

        it "returns all recs when limit is large enough" do
          @recommendation_manager.send(:filter_recs, @recommendations, { :limit => 3}).should == @recommendations
        end

        it "returns all recs when limit is bigger than the number of available recs" do
          @recommendation_manager.send(:filter_recs, @recommendations, { :limit => 4}).should == @recommendations
        end

        it "works when the video key is not the default" do
          @recommendations = @recommended_videos.map {|vid| { "rec_id" => vid.id.to_s }}
          @recommendation_manager.send(:filter_recs, @recommendations, { :limit => 3, :recommended_video_key => "rec_id"}).should == @recommendations
        end
      end

      context "return all recs with BSON Ids" do
        it "should work when the video key is a bson id" do
          Video.should_receive(:find).with(@recommended_videos[0].id).ordered.and_return(@recommended_videos[0])
          Video.should_receive(:find).with(@recommended_videos[1].id).ordered.and_return(@recommended_videos[1])
          Video.should_receive(:find).with(@recommended_videos[2].id).ordered.and_return(@recommended_videos[2])

          @recommendations = @recommended_videos.map {|vid| { :recommended_video_id => vid.id }}
          @recommendation_manager.send(:filter_recs, @recommendations, { :limit => 3}).should == @recommendations
        end
      end

      it "quits processing after it reaches the limit" do
        Video.should_receive(:find).twice().and_return(@recommended_videos[0], @recommended_videos[1])
        Video.should_not_receive(:find).with(@recommended_videos[2].id.to_s)
        @recommendation_manager.send(:filter_recs, @recommendations, { :limit => 2}).should == [
          @recommendations[0],
          @recommendations[1]
        ]
      end

      it "should skip videos whose ids are not in the Shelby DB" do
        Video.should_receive(:find).twice().and_return(nil, @recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_videos[1]).once()
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_videos[0])

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
      end

      it "should skip videos for which the block returns false" do
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([@recommended_videos[0].id.to_s])
        Video.should_receive(:find).once().with(@recommended_videos[1].id.to_s).and_return(@recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).once().with(@recommended_videos[1])

        num_calls = 0

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}){ |rec| num_calls +=1; num_calls == 2 }.should == [
          @recommendations[1]
        ]
      end

      it "should skip videos the user has already watched" do
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([@recommended_videos[0].id.to_s])
        Video.should_receive(:find).once().with(@recommended_videos[1].id.to_s).and_return(@recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).once().with(@recommended_videos[1])

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
      end

      it "should skip videos that are known to be no longer available at the provider" do
        @recommended_videos[0].available = false
        Video.should_receive(:find).twice().and_return(@recommended_videos[0], @recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).once().with(@recommended_videos[1])

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
      end

      it "should skip videos that are no longer available at the provider after re-checking" do
        Video.should_receive(:find).twice().and_return(@recommended_videos[0], @recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_videos[0]) {
          @recommended_videos[0].available = false
          nil
        }
        GT::VideoManager.should_receive(:update_video_info).with(@recommended_videos[1])
        GT::VideoManager.should_not_receive(:update_video_info).with(@recommended_videos[2])

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
      end

      it "should skip videos that are missing their thumbnails when that option is set" do
        @recommended_videos[0].thumbnail_url = nil

        Video.should_receive(:find).twice().and_return(@recommended_videos[0], @recommended_videos[1])
        GT::VideoManager.should_receive(:update_video_info).once().with(@recommended_videos[1])

        @recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[1]
        ]
      end

      it "should not skip videos that are missing their thumbnails when that option is not set" do
        @recommended_videos[0].thumbnail_url = nil

        Video.should_receive(:find).once().and_return(@recommended_videos[0])
        GT::VideoManager.should_receive(:update_video_info).once().with(@recommended_videos[0])

        rm = GT::RecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
        rm.send(:filter_recs, @recommendations, {:limit => 1}).should == [
          @recommendations[0]
        ]
      end

    end

  end

end
