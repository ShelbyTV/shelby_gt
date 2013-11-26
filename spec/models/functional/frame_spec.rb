require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Frame do

  context "database" do
    it "should have an index on [roll_id, score]" do
      indexes = Frame.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "e"=>-1})
    end

    it "should abbreviate roll_id as :a, rank as :e" do
      Frame.keys["roll_id"].abbr.should == :a
      Frame.keys["score"].abbr.should == :e
      Frame.keys["type"].abbr.should == :o
    end
  end

  context "create" do
    it "should increment it's roll's frame_count on create" do
      roll = Factory.create(:roll)
      lambda {
        frame = Factory.create(:frame, :roll => roll)
      }.should change { roll.reload.frame_count }.by(1)
    end
  end

  # We're testing a private method here, but it's a pretty fucking important/tricky one and has to be correct
  context "ancestor search" do
    it "should find an ancestor when one exists" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [@orig.id])

      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == true
    end

    it "should not find an ancestor if one doesn't exist" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [])

      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == false
    end

    it "should not find an ancestor if it's too old" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :_id => BSON::ObjectId.from_time(2.days.ago), :roll => @r2, :frame_ancestors => [@orig.id])

      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 24.hours.ago).should == false
      Frame.send(:roll_includes_ancestor_of_frame?, @r2.id, @orig.id, 3.days.ago).should == true
    end

    it "should find an ancestor after duped via Framer" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)

      @u = Factory.create(:user)
      @u.viewed_roll = Factory.create(:roll, :creator => @u)
      @u.save

      #should NOT find it now
      Frame.send(:roll_includes_ancestor_of_frame?, @u.viewed_roll_id, @orig.id, 24.hours.ago).should == false

      #dupe it
      GT::Framer.dupe_frame!(@orig, @u.id, @u.viewed_roll_id)

      #should find it now
      Frame.send(:roll_includes_ancestor_of_frame?, @u.viewed_roll_id, @orig.id, 24.hours.ago).should == true
    end
  end

  context "find video on roll" do
    it "should find the video if it's on the roll" do
      roll = Factory.create(:roll)
      video = Factory.create(:video)
      frame = Factory.create(:frame, :roll => roll, :video => video)

      Frame.roll_includes_video?(roll.id, video.id, 24.hours.ago).should == true
    end

    it "should not find the video if it's not on the roll" do
      roll = Factory.create(:roll)
      video = Factory.create(:video)
      some_other_video = Factory.create(:video)
      frame = Factory.create(:frame, :roll => roll, :video => some_other_video)

      Frame.roll_includes_video?(roll.id, video.id, 24.hours.ago).should == false
    end

    it "should not find the video if it was viewed too long ago" do
      roll = Factory.create(:roll)
      video = Factory.create(:video)
      frame = Factory.create(:frame, :_id => BSON::ObjectId.from_time(2.days.ago), :roll => roll, :video => video)

      Frame.roll_includes_video?(roll.id, video.id, 24.hours.ago).should == false
      Frame.roll_includes_video?(roll.id, video.id, 3.days.ago).should == true
    end
  end

  # We're testing a private method here, but it's a pretty fucking important/tricky one and has to be correct
  context "get ancestor" do
    it "should return an ancestor when one exists" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [@orig.id])

      Frame.send(:get_ancestor_of_frame, @r2.id, @orig.id).should == @child
    end

    it "should not find an ancestor if one doesn't exist" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)
      @child = Factory.create(:frame, :roll => @r2, :frame_ancestors => [])

      Frame.send(:get_ancestor_of_frame, @r2.id, @orig.id).should == nil
    end

    it "should find an ancestor after duped via Framer" do
      @r1 = Factory.create(:roll, :creator => Factory.create(:user))
      @r2 = Factory.create(:roll, :creator => Factory.create(:user))

      @orig = Factory.create(:frame, :roll => @r1)

      @u = Factory.create(:user)
      @u.viewed_roll = Factory.create(:roll, :creator => @u)
      @u.save

      #should NOT find it now
      Frame.send(:get_ancestor_of_frame, @u.viewed_roll_id, @orig.id).should ==  nil

      #dupe it
      child = GT::Framer.dupe_frame!(@orig, @u.id, @u.viewed_roll_id)

      #should find it now
      Frame.send(:get_ancestor_of_frame, @u.viewed_roll_id, @orig.id).should == child
    end
  end

  context "calculate like score" do
    before(:each) do
      @frame = Factory.create(:frame)
    end

    it "should give a like score of 0 when there are no likers" do
      @frame.like_count = 0
      @frame.calculate_like_score.should == 0
    end

    it "should give a like score of 1 when there is one liker" do
      @frame.like_count = 1
      @frame.calculate_like_score.should == 1.0
    end

    it "should give a like score of 2 when there are 10 likers" do
      @frame.like_count = 10
      @frame.calculate_like_score.should == 2.0
    end
  end

  context "upvoting" do
    before(:each) do
      @frame = Factory.create(:frame)
      @voter1 = Factory.create(:user)
      @voter1.upvoted_roll = Factory.create(:roll, :creator => @voter1)
      @voter1.save

      @voter2 = Factory.create(:user)
      @voter2.upvoted_roll = Factory.create(:roll, :creator => @voter2)
      @voter2.save
    end

    it "should have a baseline score > 0 after validation" do
      @frame.valid?.should == true
      @frame.score.should > 0
    end

    it "should require full User model on upvote, not just user_id" do
      lambda {
        @frame.upvote!(@voter1.id)
      }.should raise_error(ArgumentError)
    end

    xit "should update score with each new upvote" do
      @frame.upvote!(@voter1)
      score = @frame.score
      @frame.upvote!(@voter2)
      @frame.score.should > score
    end

    it "should add upvoting user to upvoters array and dupe self into user.upvoted_roll" do
      @frame.has_voted?(@voter1).should == false

      lambda {
        @frame.upvote!(@voter1)
      }.should change {Frame.count} .by 1

      @frame.has_voted?(@voter1).should == true
    end

    it "multi-upvote's should be idempotent" do
      @frame.upvote!(@voter1).should == true
      score = @frame.score
      @frame.upvote!(@voter1).should == true
      @frame.upvote!(@voter1).should == true
      @frame.upvote!(@voter1).should == true
      @frame.upvote!(@voter1).should == true
      @frame.score.should == score
      @frame.reload.score.should == score
    end
  end

  context "upvote undo" do
    before(:each) do
      @frame = Factory.create(:frame)
      @voter1 = Factory.create(:user)
      @voter1.upvoted_roll = Factory.create(:roll, :creator => @voter1)
      @voter1.save

      @voter2 = Factory.create(:user)
      @voter2.upvoted_roll = Factory.create(:roll, :creator => @voter2)
      @voter2.save

      @frame.upvote!(@voter1)
      @frame.upvote!(@voter2)
    end

    xit "should decrease score with each new upvote_undo" do
        score_before = @frame.score
        @frame.upvote_undo!(@voter1)
        @frame.score.should < score_before
    end

    it "should remove upvoting user from upvoters array and remove dupe of self from user.upvoted_roll" do
      lambda {
        @voter1.upvoted_roll.frames.count.should == 1
        @frame.upvoters.should include(@voter1.id)

        @frame.upvote_undo!(@voter1)
        @frame.upvoters.should_not include(@voter1.id)
        @frame.upvoters.should include(@voter2.id)

        @voter1.upvoted_roll.frames.count.should == 0
      }.should change { @frame.upvoters.count } .by(-1)
    end

    it "multi-un-upvotes should be idempotent" do
      @frame.upvote_undo!(@voter1).should == true
      score = @frame.score
      @frame.upvote_undo!(@voter1).should == true
      @frame.upvote_undo!(@voter1).should == true
      @frame.upvote_undo!(@voter1).should == true
      @frame.upvote_undo!(@voter1).should == true
      @frame.upvote_undo!(@voter1).should == true
      @frame.score.should == score
      @frame.reload.score.should == score
    end
  end

  context "watch later" do
    before(:each) do
      @video = Factory.create(:video)
      @frame = Factory.create(:frame, :video => @video)

      @u1 = Factory.create(:user)
      @u1.public_roll = Factory.create(:roll, :creator => @u1)
    end

    it "should require full User model, not just id" do
      lambda {
        @frame.add_to_watch_later!(@u1.id)
      }.should raise_error(ArgumentError)
    end

    it "should dupe the frame into the users public_roll, persisted" do
      f = nil
      lambda {
        f = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1

      f.persisted?.should == true
      f.roll.should == @u1.public_roll
    end

    it "should dupe the frame with a light weight frame type" do
      f = nil
      lambda {
        f = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1

      f.type.should == Frame::FRAME_TYPE[:light_weight]
    end

    it "should add the user to the frame being watch_latered's upvoters array if it's not there already" do
      @frame.add_to_watch_later!(@u1)
      @frame.add_to_watch_later!(@u1)

      @frame.upvoters.should include(@u1.id)
      @frame.upvoters.length.should == 1
    end

    it "should increment the number of likes" do
      lambda {
        @frame.add_to_watch_later!(@u1)
      }.should change { @frame.like_count } .by 1

      u2 = Factory.create(:user)
      u2.public_roll = Factory.create(:roll, :creator => u2)
      u3 = Factory.create(:user)
      u3.public_roll = Factory.create(:roll, :creator => u3)

      lambda {
        @frame.add_to_watch_later!(u2)
        @frame.add_to_watch_later!(u3)
      }.should change { @frame.like_count } .by 2
    end

    it "should increment the number of video likes" do
      lambda {
        @frame.add_to_watch_later!(@u1)
      }.should change { @video.like_count } .by 1
    end

    it "should increment the number of likes once for each user" do
      lambda {
        @frame.add_to_watch_later!(@u1)
        @frame.add_to_watch_later!(@u1)
      }.should change { @frame.like_count } .by 2
    end

    it "should increment the number of video likes once for each user" do
      lambda {
        @frame.add_to_watch_later!(@u1)
        @frame.add_to_watch_later!(@u1)
      }.should change { @video.like_count } .by 2
    end

    it "should increase the score" do
      score_before = @frame.score
      @frame.add_to_watch_later!(@u1)
      @frame.score.should > score_before
    end

    it "should set metadata correctly" do
      f = nil
      lambda {
        f = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 1

      f.creator_id.should == @frame.creator_id
      f.video_id.should == @frame.video_id
      f.conversation_id.should == @frame.conversation_id
      f.frame_ancestors.include?(@frame.id).should == true
    end

    it "should be idempotent" do
      f1, f2 = nil, nil
      lambda {
        f1 = @frame.add_to_watch_later!(@u1)
        f2 = @frame.add_to_watch_later!(@u1)
      }.should change { Frame.count } .by 2

      f1.should_not == f2
    end
  end

  context "like" do
    before(:each) do
      @video = Factory.create(:video)
      @user = Factory.create(:user)
      @roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user], :creator => @user)
      @frame = Factory.create(:frame, :roll => @roll, :creator => @user, :video => @video)
    end

    it "should increment the like count" do
      lambda {
        @frame.like!
      }.should change { @frame.like_count } .by 1
    end

    it "should increment the video like count" do
      lambda {
        @frame.like!
      }.should change { @video.like_count } .by 1
    end
  end

  context "permalinks" do

    it "should generate permalink for frame with a roll that is a user's public roll" do
      user = Factory.create(:user)
      roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user], :creator => user)
      frame = Factory.create(:frame, :roll => roll)
      frame.permalink.should == "#{Settings::ShelbyAPI.web_root}/#{user.nickname}/shares/#{frame.id}"
    end

    it "should generate permalink for frame with a roll that is not a user's public roll" do
      roll = Factory.create(:roll)
      frame = Factory.create(:frame, :roll => roll)
      frame.permalink.should == "#{Settings::ShelbyAPI.web_root}/roll/#{roll.id}/frame/#{frame.id}"
    end

    it "should generate permalink for frame without a roll" do
      video = Factory.create(:video)
      frame = Factory.create(:frame, :video => video)
      frame.permalink.should == "#{Settings::ShelbyAPI.web_root}/video/#{frame.video.provider_name}/#{frame.video.provider_id}/?frame_id=#{frame.id}"
    end

    it "should generate permalink for frame with video" do
      video = Factory.create(:video)
      frame = Factory.create(:frame, :video => video)
      frame.video_page_permalink.should == "#{Settings::ShelbyAPI.web_root}/video/#{frame.video.provider_name}/#{frame.video.provider_id}/?frame_id=#{frame.id}"
    end

  end

  context "viewed" do
    before(:each) do
      @frame = Factory.create(:frame)
      @frame.video = Factory.create(:video)
      @frame.save

      @u1 = Factory.create(:user)
      @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
      @u1.save
    end

    it "should require full User model, not just id" do
      lambda {
        @frame.view!(@u1.id)
      }.should raise_error(ArgumentError)
    end

    it "should be ok with no user also" do
      lambda {
        @frame.view!(nil)
      }.should_not raise_error
    end

    it "should dupe the frame into the users viewed_roll, persisted" do
      f = nil
      lambda {
        f = @frame.view!(@u1)
      }.should change { Frame.count } .by 1

      f.persisted?.should == true
      f.roll.should == @u1.viewed_roll
    end

    it "should set metadata correctly" do
      f = nil
      lambda {
        f = @frame.view!(@u1)
      }.should change { Frame.count } .by 1

      f.creator_id.should == @frame.creator_id
      f.video_id.should == @frame.video_id
      f.conversation_id.should == @frame.conversation_id
      f.frame_ancestors.include?(@frame.id).should == true
    end

    it "should update view_count of Frame" do
      # initiate the abbreviated view_count to make sure that gets updates on .view!
      @frame.view_count = 33
      @frame.save
      lambda {
        @frame.view!(@u1)
      }.should change { @frame.reload.view_count } .by 1

      lambda {
        Frame.should_receive(:roll_includes_ancestor_of_frame?).exactly(4).times.and_return(false)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
      }.should change { @frame.reload.view_count } .by 4
    end

    it "should update view_count of Frame's Video" do
      # initiate the abbreviated view_count to make sure that gets updates on .view!
      @frame.video.view_count = 33
      @frame.video.save
      lambda {
        @frame.view!(@u1)
      }.should change { @frame.video.reload.view_count } .by 1

      lambda {
        Frame.should_receive(:roll_includes_ancestor_of_frame?).exactly(4).times.and_return(false)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
        @frame.view!(@u1)
      }.should change { @frame.video.reload.view_count } .by 4
    end

    it "should update view_count of Frame if no user is given" do
      # initiate the abbreviated view_count to make sure that gets updates on .view!
      @frame.view_count = 33
      @frame.save
      lambda {
        @frame.view!(nil)
        @frame.view!(nil)
      }.should change { @frame.reload.view_count } .by 2
    end

    it "should update view_count of Frame's Video if no user is given" do
      # initiate the abbreviated view_count to make sure that gets updates on .view!
      @frame.video.view_count = 33
      @frame.video.save
      lambda {
        @frame.view!(nil)
        @frame.view!(nil)
      }.should change { @frame.video.reload.view_count } .by 2
    end
  end

  context "destroy" do
    before(:each) do
      @creator = Factory.create(:user)
      @stranger = Factory.create(:user)
      @stranger2 = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @stranger)
      @video = Factory.create(:video, :title => 'title')
      @frame = Factory.create(:frame, :roll => @roll, :creator => @creator, :video => @video)
      @frame_id = @frame.id
    end

    it "should allow destroy if destroyer is creator" do
      @frame.destroyable_by?(@creator).should == true
      @frame.destroyable_by?(@stranger2).should == false
    end

    it "should allow destory if creator is nil" do
      @frame.creator = nil
      @frame.save
      @frame.destroyable_by?(@creator).should == true
      @frame.destroyable_by?(@stranger).should == true
    end

    it "should allow destroy if destroyer is roll creator" do
      @frame.destroyable_by?(@stranger).should == true
    end

    it "should decrement it's roll's frame_count on destroy" do
      lambda {
        @frame.destroy
      }.should change { @roll.reload.frame_count }.by -1
    end

    it "should still be in the DB" do
      @frame.destroy.should == true

      Frame.find(@frame_id).should_not == nil
    end

    it "should have a nil roll_id" do
      @frame.destroy

      Frame.find(@frame_id).roll_id.should == nil
    end


    it "should have the original roll_id in deleted_from_roll_id" do
      @frame.destroy

      Frame.find(@frame_id).deleted_from_roll_id.should == @roll.id
      Frame.find(@frame_id).virtually_destroyed?.should == true
    end

    context "frame on watch later roll" do
        before(:each) do
          @stranger_public_roll = Factory.create(:roll, :creator => @stranger, :roll_type => Roll::TYPES[:special_watch_later])
          @stranger.public_roll = @stranger_public_roll

          @stranger2_public_roll = Factory.create(:roll, :creator => @stranger2, :roll_type => Roll::TYPES[:special_watch_later])
          @stranger2.public_roll = @stranger2_public_roll

          @frame.add_to_watch_later!(@stranger)
          @frame.add_to_watch_later!(@stranger2)
        end

        it "should remove the user as an upvoter of the frame's ancestor (original upvoted frame)" do
          @stranger_public_roll.frames.first.destroy
          @frame.reload
          @frame.upvoters.should_not include(@stranger.id)
          @frame.upvoters.should include(@stranger2.id)
          @frame.upvoters.length.should == 1
        end

        it "should decrement the number of likes of the frame's ancestor (original upvoted frame)" do
          lambda {
            @stranger_public_roll.frames.first.destroy
            @frame.reload
          }.should change { @frame.like_count } .by(-1)
        end

        it "should decrement the number of likes of the video of the frame's ancestor (original upvoted frame)" do
          lambda {
            @stranger_public_roll.frames.first.destroy
            @video.reload
          }.should change { @video.like_count } .by(-1)
        end

        it "should decrease score of the frame's ancestor (original upvoted frame)" do
          score_before = @frame.score
          @stranger_public_roll.frames.first.destroy
          @frame.reload
          @frame.score.should < score_before
        end
    end

  end

end
