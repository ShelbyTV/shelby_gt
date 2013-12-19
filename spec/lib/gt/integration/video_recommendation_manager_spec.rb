require 'spec_helper'
require 'video_recommendation_manager'

# INTEGRATION test
describe GT::VideoRecommendationManager do
  before(:each) do
    GT::VideoProviderApi.stub(:get_video_info)
  end

  context "get_video_graph_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = []
      @src_frame_ids = []
      @dbes = []
      # create dashboard entries 0 to n, entry i will have i recommendations attached to its video
      4.times do |i|
        v = Factory.create(:video)
        recs_for_this_video = []
        sharer = Factory.create(:user)
        f = Factory.create(:frame, :video => v, :creator => sharer )

        i.times do |j|
          rec_vid = Factory.create(:video)
          rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
          v.recs << rec
          recs_for_this_video << rec_vid
          @src_frame_ids.unshift f.id
        end

        @recommended_videos.unshift recs_for_this_video

        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :actor => sharer)
        @dbes.unshift dbe
      end

      @recommended_videos.flatten!

      @video_recommendation_manager = GT::VideoRecommendationManager.new(@user)
    end

    it "should return all of the recommendations when there are no restricting limits" do
      MongoMapper::Plugins::IdentityMap.clear
      Array.any_instance.should_receive(:shuffle!).and_call_original

      result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
      result_video_ids = result.map{|rec|rec[:recommended_video_id]}
      result_video_ids.length.should == @recommended_videos.length
      (result_video_ids - @recommended_videos.map { |v| v.id }).should == []
    end

    context "stub shuffle! so we can test everything else more carefully " do

      before(:each) do
        Array.any_instance.stub(:shuffle!)
      end

      it "should return all of the recommendations when there are no restricting limits" do
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length
        result.should == @recommended_videos.each_with_index.map{|vid, i| {:recommended_video_id => vid.id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude videos the user has already watched" do
        @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
        @viewed_roll.frames << @viewed_frame
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should exclude videos that are no longer available at the provider" do
        @recommended_videos[0].available = false
        @recommended_videos[0].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "moves on to find more videos after skipping ones that are not available at the provider" do
        @recommended_videos[0].available = false
        @recommended_videos[0].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 1, nil, nil, {:unique_sharers_only => false})
        result.length.should == 1
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should exclude videos that are missing their thumbnails when that option is set" do
        @recommended_videos[0].thumbnail_url = nil
        @recommended_videos[0].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
      end

      it "should not exclude videos that are missing their thumbnails when that option is not set" do
        @recommended_videos[0].thumbnail_url = nil
        @recommended_videos[0].save
        MongoMapper::Plugins::IdentityMap.clear

        rm = GT::VideoRecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
        result = rm.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length
        result.should == @recommended_videos.each_with_index.map{|vid, i| {:recommended_video_id => vid.id, :src_frame_id => @src_frame_ids[i]}}
      end

      it "should exclude from consideration dashboard entries that have no actor" do
        @dbes[2].actor_id = nil
        @dbes[2].save
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos.last.id, :src_frame_id => @src_frame_ids.last})
        result.should include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
      end

      it "should return a maximum of one video from a given source sharer, by default" do
        MongoMapper::Plugins::IdentityMap.clear

        result = @video_recommendation_manager.get_video_graph_recs_for_user(10, 10)
        result.length.should == 3
        result.should include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should include({:recommended_video_id => @recommended_videos[3].id, :src_frame_id => @src_frame_ids[3]})
        result.should include({:recommended_video_id => @recommended_videos[5].id, :src_frame_id => @src_frame_ids[5]})
      end

      it "returns the proper number of recs based on the limit parameter" do
        MongoMapper::Plugins::IdentityMap.clear

        @video_recommendation_manager.get_video_graph_recs_for_user(10, 1, nil, nil, {:unique_sharers_only => false}).should == [
          {:recommended_video_id => @dbes.first.video.recs.first.recommended_video_id, :src_frame_id => @dbes.first.frame_id}
        ]
        @video_recommendation_manager.get_video_graph_recs_for_user(10, 2, nil, nil, {:unique_sharers_only => false}).should == [
          {:recommended_video_id => @dbes.first.video.recs[0].recommended_video_id, :src_frame_id => @dbes[0].frame_id},
          {:recommended_video_id => @dbes.first.video.recs[1].recommended_video_id, :src_frame_id => @dbes[0].frame_id}
        ]
      end

      it "excludes videos from specified excluded sharers" do
        MongoMapper::Plugins::IdentityMap.clear

        rm = GT::VideoRecommendationManager.new(@user, {:excluded_sharer_ids => [@dbes[0].actor_id]})
        result = rm.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 3
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should_not include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
        result.should_not include({:recommended_video_id => @recommended_videos[2].id, :src_frame_id => @src_frame_ids[2]})
        result.should include({:recommended_video_id => @recommended_videos.last.id, :src_frame_id => @src_frame_ids.last})

        rm = GT::VideoRecommendationManager.new(@user, {:excluded_sharer_ids => [@dbes[0].actor_id.to_s]})
        result = rm.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 3
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
        result.should_not include({:recommended_video_id => @recommended_videos[1].id, :src_frame_id => @src_frame_ids[1]})
        result.should_not include({:recommended_video_id => @recommended_videos[2].id, :src_frame_id => @src_frame_ids[2]})
        result.should include({:recommended_video_id => @recommended_videos.last.id, :src_frame_id => @src_frame_ids.last})
      end

      it "excludes videos with specified excluded ids" do
        MongoMapper::Plugins::IdentityMap.clear

        rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@recommended_videos[0].id]})
        result = rm.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})

        rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@recommended_videos[0].id.to_s]})
        result = rm.get_video_graph_recs_for_user(10, 10, nil, nil, {:unique_sharers_only => false})
        result.length.should == @recommended_videos.length - 1
        result.should_not include({:recommended_video_id => @recommended_videos[0].id, :src_frame_id => @src_frame_ids[0]})
      end

    end

  end

  context "if_no_recent_recs_generate_rec" do

    before(:each) do
      @user = Factory.create(:user)
    end

    context "no recommendations yet within the recent limit number of frames" do

      context "video graph wins random choice" do

        before(:each) do
          Random.stub(:rand).and_return(Settings::Recommendations.triggered_ios_recs[:mortar_recs_weight])
        end

        context "no recommendations avaialable" do

          it "returns nil and creates no dashboard entries" do
            expect {
              @result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            }.to_not change(DashboardEntry, :count)
            @result.should be_nil
          end

        end

        context "video graph recommendations available" do

          before(:each) do
            v = Factory.create(:video)
            @rec_vid = Factory.create(:video)
            rec = Factory.create(:recommendation, :recommended_video_id => @rec_vid.id, :score => 100.0)
            v.recs << rec
            v.save

            sharer = Factory.create(:user)
            @f = Factory.create(:frame, :video => v, :creator => sharer )

            @dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame], :actor => sharer)
            @dbe.save
          end

          it "should return a new dashboard entry with a video graph recommendation" do
            MongoMapper::Plugins::IdentityMap.clear

            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            result.should be_an_instance_of(DashboardEntry)
            result.src_frame.should == @f
            result.video_id.should == @rec_vid.id
            result.action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
          end

          it "doesn't consider notification dbes when scanning back to see if a rec is needed" do
            MongoMapper::Plugins::IdentityMap.clear

            # put a recommendation in the dashboard
            GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user, {:insert_at_random_location => false})
            # space it out from the current location with enough intervening notification entries to put
            # the recommendation entry outide of the slice that we normally look at
            Settings::Recommendations.triggered_ios_recs[:num_recents_to_check].times do |i|
              action = (i % 4) + DashboardEntry::ENTRY_TYPE[:like_notification]
              Factory.create(
                :dashboard_entry,
                :user => @user,
                :action => action
              ).save
            end
            MongoMapper::Plugins::IdentityMap.clear

            # since notification entries aren't visible in the stream,
            # the next visible Recommendation entry is one entry behind the head, so we shouldn't put another one
            expect {
              @result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            }.not_to change {"#{DashboardEntry.count},#{Frame.count},#{Conversation.count}"}

            @result.should be_nil
          end

          it "doesnt return a recommendation if the video doesn't have a thumbnail" do
            @rec_vid.thumbnail_url = nil
            @rec_vid.save
            MongoMapper::Plugins::IdentityMap.clear

            expect {
              @result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            }.to_not change(DashboardEntry, :count)
            @result.should be_nil
          end

          it "should create the newest entry in the dashboard by default" do
            MongoMapper::Plugins::IdentityMap.clear

            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            result.should == DashboardEntry.sort(:id.desc).first
          end

          it "should insert the newest entry just after a randomly selected dbentry if options[:insert_at_random_locations] is specified" do
            MongoMapper::Plugins::IdentityMap.clear

            Array.any_instance.stub(:sample).and_return(@dbe)
            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user, {:insert_at_random_location => true})
            result.id.generation_time.to_i.should == @dbe.id.generation_time.to_i - 1
          end

          context "database peristence" do
            before(:each) do
              MongoMapper::Plugins::IdentityMap.clear

              @lambda = lambda {
                GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
              }
            end

            it "should persist a new dashboard entry to the database" do
              @lambda.should change { DashboardEntry.count }
            end

            it "should persist a new frame to the database" do
              @lambda.should change { Frame.count }
            end

            it "should persist a conversation because the frame is being persisted" do
              @lambda.should change { Conversation.count }
            end

          end

        end

        context "mortar recommendations available but no video graph recs available" do

          before(:each) do
            @recommended_video = Factory.create(:video)
            @reason_video = Factory.create(:video)

            @mortar_recommendations = [
              {"item_id" => @recommended_video.id.to_s, "reason_id" => @reason_video.id.to_s},
            ]
            @mortar_recommendations.stub(:shuffle!)
            GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_recommendations)

            MongoMapper::Plugins::IdentityMap.clear
          end

          it "fills in and returns a new dashboard entry with a mortar recommendation" do
            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            result.should be_an_instance_of(DashboardEntry)
            result.src_video.should == @reason_video
            result.video_id.should == @recommended_video.id
            result.action.should == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          end

          it "does not fill in mortar recommendations if {:include_mortar_recs => false} is passed" do
            GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user, {:include_mortar_recs => false}).should be_nil
          end

        end

      end

      context "mortar wins random choice" do

        before(:each) do
          Random.stub(:rand).and_return(Settings::Recommendations.triggered_ios_recs[:mortar_recs_weight] - 0.01)
        end

        context "no recommendations avaialable" do

          it "returns nil and creates no dashboard entries" do
            expect {
              @result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            }.to_not change(DashboardEntry, :count)
            @result.should be_nil
          end

        end

        context "mortar recommendations available" do

          before(:each) do
            @recommended_video = Factory.create(:video)
            @reason_video = Factory.create(:video)

            @mortar_recommendations = [
              {"item_id" => @recommended_video.id.to_s, "reason_id" => @reason_video.id.to_s},
            ]
            @mortar_recommendations.stub(:shuffle!)
            GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_recommendations)

            MongoMapper::Plugins::IdentityMap.clear
          end

          it "returns a new dashboard entry with a mortar recommendation" do
            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            result.should be_an_instance_of(DashboardEntry)
            result.src_video.should == @reason_video
            result.video_id.should == @recommended_video.id
            result.action.should == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          end

          it "ignores the random chance and tries to return a video graph rec if {:include_mortar_recs => false} is passed" do
            GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user, {:include_mortar_recs => false}).should be_nil
          end

        end

        context "video graph recommendations available but no mortar recs available" do

          it "fills in and returns a new dashboard entry with a video graph recommendation" do
            v = Factory.create(:video)
            @rec_vid = Factory.create(:video)
            rec = Factory.create(:recommendation, :recommended_video_id => @rec_vid.id, :score => 100.0)
            v.recs << rec
            v.save

            sharer = Factory.create(:user)
            @f = Factory.create(:frame, :video => v, :creator => sharer )

            @dbe = Factory.create(:dashboard_entry, :frame => @f, :user => @user, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame], :actor => sharer)
            @dbe.save

            MongoMapper::Plugins::IdentityMap.clear

            result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
            result.should be_an_instance_of(DashboardEntry)
            result.src_frame.should == @f
            result.video_id.should == @rec_vid.id
            result.action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
          end

        end

      end

    end

    context "recommendations exist within the recent limit number of frames" do

      it "should return nil because no new dashboard entries need to be created" do
        MongoMapper::Plugins::IdentityMap.clear

        # put a recommendation in the dashboard
        GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
        # check if we need to put another one
        result = GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
        # since there's already a recommendation in the last five (the one we just created), we shouldn't put another
        result.should be_nil
      end

      it "should not persist any new dashboard entries, frames, or conversations to the database" do
        MongoMapper::Plugins::IdentityMap.clear

        # put a recommendation in the dashboard
        GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)

        lambda {
          # check if we need to put another one
          GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(@user)
          # since there's already a recommendation in the last five (the one we just created), we shouldn't put another
        }.should_not change {"#{DashboardEntry.count},#{Frame.count},#{Conversation.count}"}
      end

    end

  end

  context "create_recommendation_dbentry" do
    before(:each) do
      @user = Factory.create(:user)
      @rec_vid = Factory.create(:video)
    end

    it "should create a db entry for a video graph recommendation with the corresponding video, action, and src_frame" do
      src_frame = Factory.create(:frame)
      MongoMapper::Plugins::IdentityMap.clear

      result = GT::VideoRecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        {
          :src_id => src_frame.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      result[:dashboard_entry].src_frame.should == src_frame

      result[:frame].should be_a Frame
      result[:frame].video.should == @rec_vid
    end

    context "database persistence" do

      context "persist by default" do
        before(:each) do
          MongoMapper::Plugins::IdentityMap.clear

          @lambda = lambda {
            GT::VideoRecommendationManager.create_recommendation_dbentry(
              @user,
              @rec_vid.id,
              DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
              {
                :src_id => nil
              }
            )
          }
        end

        it "should persist a new dashboard entry to the database" do
          @lambda.should change { DashboardEntry.count }
        end

        it "should persist a new frame to the database" do
          @lambda.should change { Frame.count }
        end

        it "should persist a conversation because the frame is being persisted" do
          @lambda.should change { Conversation.count }
        end
      end

      it "should not persist when persist false option is passed" do
        MongoMapper::Plugins::IdentityMap.clear

        lambda {
          GT::VideoRecommendationManager.create_recommendation_dbentry(
            @user,
            @rec_vid.id,
            DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
            {
              :src_id => nil,
              :persist => false
            }
          )
        }.should_not change { "#{DashboardEntry.count},#{Frame.count},#{Conversation.count}" }
      end

      context "channel recommendation" do
        context "persist by default" do
          before(:each) do
            src_frame = Factory.create(:frame)
            MongoMapper::Plugins::IdentityMap.clear

            @lambda = lambda {
              GT::VideoRecommendationManager.create_recommendation_dbentry(
                @user,
                @rec_vid.id,
                DashboardEntry::ENTRY_TYPE[:channel_recommendation],
                {
                  :src_id => src_frame.id
                }
              )
            }
          end

          it "should persist a new dashboard entry to the database" do
            @lambda.should change { DashboardEntry.count }
          end

          it "should not persist a new frame because it's using an existing one" do
            @lambda.should_not change { Frame.count }
          end

          it "should not persist a conversation because a frame is not being persisted" do
            @lambda.should_not change { Conversation.count }
          end
        end

        it "should not persist when persist false option is passed" do
          src_frame = Factory.create(:frame)
          MongoMapper::Plugins::IdentityMap.clear

          lambda {
            GT::VideoRecommendationManager.create_recommendation_dbentry(
              @user,
              @rec_vid.id,
              DashboardEntry::ENTRY_TYPE[:channel_recommendation],
              {
                :src_id => src_frame.id,
                :persist => false
              }
            )
          }.should_not change { "#{DashboardEntry.count},#{Frame.count},#{Conversation.count}" }
        end
      end

    end

    it "should create a db entry for a mortar recommendation with the corresponding video, action, and src_video" do
      src_video = Factory.create(:video)
      MongoMapper::Plugins::IdentityMap.clear

      result = GT::VideoRecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        {
          :src_id => src_video.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      result[:dashboard_entry].src_video.should == src_video

      result[:frame].should be_a Frame
      result[:frame].video.should == @rec_vid
    end

    it "should create a db entry for a channel recommendation with the corresponding frame, video, and action" do
      src_frame = Factory.create(:frame, :video => @rec_vid)
      MongoMapper::Plugins::IdentityMap.clear

      result = GT::VideoRecommendationManager.create_recommendation_dbentry(
        @user,
        @rec_vid.id,
        DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        {
          :src_id => src_frame.id
        }
      )

      result[:dashboard_entry].should be_a DashboardEntry
      result[:dashboard_entry].user.should == @user
      result[:dashboard_entry].video.should == @rec_vid
      result[:dashboard_entry].action.should == DashboardEntry::ENTRY_TYPE[:channel_recommendation]

      result[:frame].should == src_frame
    end
  end

  context "get_mortar_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
      @reason_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]

      @mortar_recommendations = [
        {"item_id" => @recommended_videos[0].id.to_s, "reason_id" => @reason_videos[0].id.to_s},
        {"item_id" => @recommended_videos[1].id.to_s, "reason_id" => @reason_videos[1].id.to_s},
        {"item_id" => @recommended_videos[2].id.to_s, "reason_id" => @reason_videos[2].id.to_s}
      ]
      @mortar_recommendations.stub(:shuffle!)
      GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_recommendations)

      @video_recommendation_manager = GT::VideoRecommendationManager.new(@user)
    end

    it "should return the recommended videos" do
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_mortar_recs_for_user.length.should == 1
      @video_recommendation_manager.get_mortar_recs_for_user(2).length.should == 2
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

    it "should skip videos that are no longer available at the provider" do
      @recommended_videos[0].available = false
      @recommended_videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

    it "should skip videos that are missing their thumbnails when that option is set" do
      @recommended_videos[0].thumbnail_url = nil
      @recommended_videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

    it "should not skip videos that are missing their thumbnails when that option is not set" do
      @recommended_videos[0].thumbnail_url = nil
      @recommended_videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
      rm.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[0].id,
          :src_id => @reason_videos[0].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

    it "excludes videos with specified excluded ids" do
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@recommended_videos[0].id]})
      rm.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@recommended_videos[0].id.to_s]})
      rm.get_mortar_recs_for_user.should ==
        [{
          :recommended_video_id => @recommended_videos[1].id,
          :src_id => @reason_videos[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        }]
    end

  end

  context "get_channel_recs_for_user" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
      @channel_user = Factory.create(:user)
      Settings::Channels['featured_channel_user_id'] = @channel_user.id.to_s

      @dbes = []
      @videos = []
      @frames = []
      @sharers = []
      3.times do
        video = Factory.create(:video)
        @videos.unshift video
        sharer = Factory.create(:user)
        frame = Factory.create(:frame, :video_id => video.id, :creator_id => sharer.id)
        @frames.unshift frame
        @sharers.unshift sharer
        @dbes.unshift Factory.create(:dashboard_entry, :user_id => @channel_user.id, :frame_id => frame.id, :video_id => video.id, :actor_id => sharer.id)
      end

      Array.any_instance.stub(:shuffle!)

      @video_recommendation_manager = GT::VideoRecommendationManager.new(@user)
    end

    it "should return the recommended videos" do
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id).length.should == 1
      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id, 2).length.should == 2
    end

    it "doesn't consider notification dbes" do
      video = Factory.create(:video)
      frame = Factory.create(:frame, :video_id => video.id, :creator_id => @channel_user.id)
      liker = Factory.create(:user)
      Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:like_notification], :user_id => @channel_user.id, :frame_id => frame.id, :video_id => video.id, :actor_id => liker.id)
      MongoMapper::Plugins::IdentityMap.clear

      result = @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id, 4)
      result.length.should == 3
      result.map {|rec| rec[:recommended_video_id]}.should_not include video.id
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should skip videos that are no longer available at the provider" do
      @videos[0].available = false
      @videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should skip frames that were created by the user for whom recommendations are being generated" do
      @dbes[0].actor_id = @user.id
      @dbes[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should skip videos that are missing their thumbnails when that option is set" do
      @videos[0].thumbnail_url = nil
      @videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[1].id,
          :src_id => @frames[1].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should not skip videos that are missing their thumbnails when that option is not set" do
      @videos[0].thumbnail_url = nil
      @videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:exclude_missing_thumbnails => false})
      rm.get_channel_recs_for_user(@channel_user.id).should ==
        [{
          :recommended_video_id => @videos[0].id,
          :src_id => @frames[0].id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }]
    end

    it "should return a maximum of one video from a given sharer, by default" do
      @dbes[1].actor_id = @dbes[0].actor_id
      @dbes[1].save
      MongoMapper::Plugins::IdentityMap.clear

      result = @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id, 3)
      result.length.should == 2
      result.map {|rec| rec[:recommended_video_id]}.should_not include @videos[1].id
    end

    it "should not limit the number of videos from a given sharer if :unique_sharers_only is false" do
      @dbes[1].actor_id = @dbes[0].actor_id
      @dbes[1].save
      MongoMapper::Plugins::IdentityMap.clear

      result = @video_recommendation_manager.get_channel_recs_for_user(@channel_user.id, 3, {:unique_sharers_only => false})
      result.length.should == 3
      result.map {|rec| rec[:recommended_video_id]}.should include @videos[1].id
    end

    it "excludes videos from specified excluded sharers" do
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_sharer_ids => [@dbes[0].actor_id]})
      result = rm.get_channel_recs_for_user(@channel_user.id, 3)
      result.length.should == 2
      result.map {|rec| rec[:recommended_video_id]}.should_not include @videos[0].id

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_sharer_ids => [@dbes[0].actor_id.to_s]})
      result = rm.get_channel_recs_for_user(@channel_user.id, 3)
      result.length.should == 2
      result.map {|rec| rec[:recommended_video_id]}.should_not include @videos[0].id
    end

    it "excludes videos with specified excluded ids" do
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@videos[0].id]})
      result = rm.get_channel_recs_for_user(@channel_user.id, 3)
      result.length.should == 2
      result.map {|rec| rec[:recommended_video_id]}.should_not include @videos[0].id

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@videos[0].id.to_s]})
      result = rm.get_channel_recs_for_user(@channel_user.id, 3)
      result.length.should == 2
      result.map {|rec| rec[:recommended_video_id]}.should_not include @videos[0].id
    end

  end

  context "get_recs_for_user" do
    before(:each) do
      @user = Factory.create(:user)
      @featured_channel_user = Factory.create(:user)
      Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
      @video_recommendation_manager = GT::VideoRecommendationManager.new(@user)

      Array.any_instance.stub(:shuffle!)

      #create a video graph rec
      v = Factory.create(:video)
      @vid_graph_recommended_vid = Factory.create(:video)
      rec = Factory.create(:recommendation, :recommended_video_id => @vid_graph_recommended_vid.id, :score => 100.0)
      v.recs << rec

      v.save

      @vid_graph_src_frame_creator = Factory.create(:user)
      @vid_graph_src_frame = Factory.create(:frame, :video => v, :creator => @vid_graph_src_frame_creator )

      dbe = Factory.create(:dashboard_entry, :frame => @vid_graph_src_frame, :user => @user, :video_id => v.id, :actor => @vid_graph_src_frame_creator)

      dbe.save

      #create a mortar rec
      @mortar_recommended_vid = Factory.create(:video)
      @mortar_src_vid = Factory.create(:video)
      mortar_response = [{"item_id" => @mortar_recommended_vid.id.to_s, "reason_id" => @mortar_src_vid.id.to_s}]

      GT::MortarHarvester.stub(:get_recs_for_user).and_return(mortar_response)

      #create a channel rec
      @featured_curator = Factory.create(:user)
      @conversation = Factory.create(:conversation)
      @message = Factory.create(:message, :text => "Some interesting text", :user_id => @featured_curator.id)
      @conversation.messages << @message
      @conversation.save

      @channel_recommended_vid = Factory.create(:video)
      @community_channel_frame = Factory.create(:frame, :creator_id => @featured_curator.id, :video_id => @channel_recommended_vid.id, :conversation_id => @conversation.id)
      @community_channel_dbes = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => @community_channel_frame.id, :video_id => @channel_recommended_vid.id, :actor_id => @featured_curator.id)
    end

    it "returns the right results" do
      MongoMapper::Plugins::IdentityMap.clear

      res = @video_recommendation_manager.get_recs_for_user({ :sources => [31, 33, 34], :limits => [1, 1, 1] })
      res.length.should == 3
      res[0].should == {
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :recommended_video_id => @vid_graph_recommended_vid.id,
        :src_id => @vid_graph_src_frame.id
      }
      res[1].should == {
        :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        :recommended_video_id => @mortar_recommended_vid.id,
        :src_id => @mortar_src_vid.id
      }
      res[2].should == {
        :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation],
        :recommended_video_id => @channel_recommended_vid.id,
        :src_id => @community_channel_frame.id
      }
    end

    it "fills in from a source with limit zero" do
      MongoMapper::Plugins::IdentityMap.clear

      res = @video_recommendation_manager.get_recs_for_user({ :sources => [31, 33], :limits => [2, 0] })
      res.length.should == 2
      res[0].should == {
        :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
        :recommended_video_id => @vid_graph_recommended_vid.id,
        :src_id => @vid_graph_src_frame.id
      }
      res[1].should == {
        :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation],
        :recommended_video_id => @mortar_recommended_vid.id,
        :src_id => @mortar_src_vid.id
      }
    end

    it "does not make recommendations based on the specified excluded source sharers" do
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_sharer_ids => [@vid_graph_src_frame_creator.id, @featured_curator.id]})
      rm.get_recs_for_user({ :sources => [31, 33, 34], :limits => [1, 1, 1] }).length.should == 1
    end

    it "excludes videos from the specified list of excluded video ids" do
      MongoMapper::Plugins::IdentityMap.clear

      rm = GT::VideoRecommendationManager.new(@user, {:excluded_video_ids => [@vid_graph_recommended_vid.id, @mortar_recommended_vid.id, @channel_recommended_vid.id]})
      rm.get_recs_for_user({ :sources => [31, 33, 34], :limits => [1, 1, 1] }).length.should == 0
    end

  end

  context "filter_recs" do
    before(:each) do
      @viewed_roll = Factory.create(:roll)
      @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)

      @recommended_videos = [Factory.create(:video), Factory.create(:video), Factory.create(:video)]
      @recommendations = @recommended_videos.map {|vid| { :recommended_video_id => vid.id.to_s }}

      @video_recommendation_manager = GT::VideoRecommendationManager.new(@user)
    end

    it "return all recs" do
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.send(:filter_recs, @recommendations).should == @recommendations
    end

    it "should skip videos the user has already watched" do
      @viewed_frame = Factory.create(:frame, :video_id => @recommended_videos[0].id, :creator => @user)
      @viewed_roll.frames << @viewed_frame
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
        @recommendations[1]
      ]
    end

    it "should skip videos that are no longer available at the provider" do
      @recommended_videos[0].available = false
      @recommended_videos[0].save
      MongoMapper::Plugins::IdentityMap.clear

      @video_recommendation_manager.send(:filter_recs, @recommendations, {:limit => 1}).should == [
        @recommendations[1]
      ]
    end

  end

  context "instance state" do

    context "excluding watched videos" do

      it "only loads watched videos once across multiple calls to a VideoRecommendationManager instance" do
        @viewed_roll = Factory.create(:roll)
        @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
        @featured_channel_user = Factory.create(:user)
        Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s

        # create a video graph recommendation
        v = Factory.create(:video)

        sharer = Factory.create(:user)
        f = Factory.create(:frame, :video => v, :creator => sharer )

        rec_vid = Factory.create(:video)
        rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
        v.recs << rec
        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :actor => sharer)
        dbe.save

        @frame_query = double("frame_query")
        @frame_query.stub_chain(:fields, :limit, :all, :map).and_return([])
        Frame.should_receive(:where).with(:roll_id => @viewed_roll.id).exactly(1).times.and_call_original

        MongoMapper::Plugins::IdentityMap.clear

        rm = GT::VideoRecommendationManager.new(@user)
        rm.get_video_graph_recs_for_user(10, nil)
        rm.get_channel_recs_for_user(@featured_channel_user.id)
      end

    end

  end

  context "excluding duplicate source sharer" do

    it "only returns one recommendation from a given source sharer per VideoRecommendationManager instance, when that option is set" do
        @viewed_roll = Factory.create(:roll)
        @user = Factory.create(:user, :viewed_roll_id => @viewed_roll.id)
        @featured_channel_user = Factory.create(:user)
        Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s

        # create a video graph recommendation
        v = Factory.create(:video)

        sharer = Factory.create(:user)
        f = Factory.create(:frame, :video => v, :creator => sharer )

        rec_vid = Factory.create(:video)
        rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id)
        v.recs << rec
        v.save

        dbe = Factory.create(:dashboard_entry, :frame => f, :user => @user, :video_id => v.id, :actor => sharer)
        dbe.save

        # create a featured recommendation from the same source sharer
        video = Factory.create(:video)
        frame = Factory.create(:frame, :video_id => video.id, :creator_id => sharer.id)
        dbe = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => frame.id, :video_id => video.id, :actor_id => sharer.id)

        MongoMapper::Plugins::IdentityMap.clear

        rm = GT::VideoRecommendationManager.new(@user)
        rm.get_video_graph_recs_for_user(1).length.should == 1
        # by default, we don't allow multiple recs from the same source sharer
        rm.get_channel_recs_for_user(@featured_channel_user.id, 1).length.should == 0
        # if we explicitly allow repeated source sharers, we should get a channel recommendation
        rm.get_channel_recs_for_user(@featured_channel_user.id, 1, {:unique_sharers_only => false}).length.should == 1
    end

  end

end
