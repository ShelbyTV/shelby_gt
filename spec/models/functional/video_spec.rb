require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Video do
  before(:each) do
    @video = Factory.create(:video)
  end

  context "database" do

    it "should have an index on [provider_name, provider_id]" do
      indexes = Video.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "b"=>1})
    end

    it "should abbreviate a as :provider_name, b as :provider_id" do
      Video.keys["provider_name"].abbr.should == :a
      Video.keys["provider_id"].abbr.should == :b
    end

    it "should have a default value of true for :available" do
      @video.available.should == true
    end

  end

  context "before_create" do
    it "fills the video's info_updated_at Time on creation" do
      expect(@video.info_updated_at).to be_a(Time)
    end
  end

  context "validations" do

    it "should validate uniqueness of provider_name and provider_id (when arnold performance settings aren't on)" do
      v = Video.new
      v.provider_name = @video.provider_name
      v.provider_id = @video.provider_id
      v.valid?.should == false
      v.save.should == false
      v.errors.messages.include?(:provider_id).should == true
    end

    it "should allow overlapping provider_id at different provider_name" do
      v = Video.new
      v.provider_name = "#{@video.provider_name}-2"
      v.provider_id = @video.provider_id
      v.valid?.should == true
      v.save.should == true
    end

    it "should throw error when trying to create a video where index (ie provider_name + provider_id) already exists"  do
      lambda {
        v = Video.new
        v.provider_name = "yt"
        v.provider_id = 'this_id_is_soooo_unique'
        v.save
      }.should change {Video.count} .by 1
      lambda {
        v = Video.new
        v.provider_name = "yt"
        v.provider_id = 'this_id_is_soooo_unique'
        v.save(:validate => false)
      }.should raise_error Mongo::OperationFailure
    end

  end

  context "permalinks" do
    before(:each) do
      @video.title = 'Title with spaces'
    end

    it "should generate a permalink" do
      @video.permalink.should == "#{Settings::ShelbyAPI.web_root}/video/#{@video.provider_name}/#{@video.provider_id}/title-with-spaces"
    end

    it "should generate a video page permalink (identical to its regular permalink)" do
      @video.video_page_permalink.should == "#{Settings::ShelbyAPI.web_root}/video/#{@video.provider_name}/#{@video.provider_id}/title-with-spaces"
    end

    it "should generate a subdomain permalink (identical to its regular permalink)" do
      @video.subdomain_permalink.should == "#{Settings::ShelbyAPI.web_root}/video/#{@video.provider_name}/#{@video.provider_id}/title-with-spaces"
    end

  end

  context "viewed" do
    before(:each) do
      @user = Factory.create(:user)
      @user.viewed_roll = Factory.create(:roll, :creator => @user)
      @user.save
    end

    it "should require full User model, not just id" do
      lambda {
        @video.view!(@user.id)
      }.should raise_error(ArgumentError)
    end

    it "should be ok with no user also" do
      lambda {
        @video.view!(nil)
      }.should_not raise_error
    end

    it "should update view_count of Video" do
      lambda {
        @video.view!(@user)
      }.should change { @video.reload.view_count } .by 1

      lambda {
        @video.view!(nil)
      }.should change { @video.reload.view_count } .by 1
    end

    it "should return the video if the view_count was updated" do
      @video.view!(@user).should == @video
      @video.view!(nil).should == @video
    end

    it "should create a frame on the users viewed_roll, persisted" do
      v = nil
      lambda {
        v = @video.view!(@user)
      }.should change { Frame.count } .by 1

      f = Frame.last

      f.persisted?.should == true
      f.creator.should == @user
      f.video.should == @video
      f.roll.should == @user.viewed_roll
    end

    it "should not create any dashboard entries" do
      GT::Framer.should_not_receive(:create_dashboard_entries)
      @video.view!(@user)
    end

    it "should not create any frames if no user is passed in" do
      lambda {
        @video.view!(nil)
      }.should_not change { Frame.count }
    end

    it "should not do anything if this video was added to the viewed roll in the last day" do
      @user.viewed_roll.frames << Factory.create(:frame, :video => @video)

      @video.view!(@user).should == false

      lambda {
        @video.view!(@user)
      }.should_not change { @video.reload.view_count }

      lambda {
        @video.view!(@user)
      }.should_not change { Frame.count }
    end

  end

  context "like!" do

    before(:each) do
      @liker1 = Factory.create(:user)
      @liker2 = Factory.create(:user)
      MongoMapper::Plugins::IdentityMap.clear
    end

    it "updates like and liker counts" do
      expect{@video.like!(@liker1)}.to change(@video, :like_count).by(1)
      expect{@video.like!(@liker2)}.to change(@video, :tracked_liker_count).by(1)
    end

    it "creates a VideoLikerBucket and inserts a VideoLiker document" do
      expect{@video.like!(@liker1)}.to change(VideoLikerBucket, :count).by(1)

      video_liker_bucket = VideoLikerBucket.last
      expect(video_liker_bucket.provider_name).to eq @video.provider_name
      expect(video_liker_bucket.provider_id).to eq @video.provider_id

      video_liker = video_liker_bucket.likers.last
      expect(video_liker.user_id).to eq @liker1.id
    end

    it "does not update liker count when the liker is an anonymous user" do
      @liker1.user_type = User::USER_TYPE[:anonymous]
      @liker2.user_type = User::USER_TYPE[:anonymous]
      expect{@video.like!(@liker1)}.to change(@video, :like_count).by(1)
      expect{@video.like!(@liker2)}.not_to change(@video, :tracked_liker_count)
    end

    it "does not create a VideoLikerBucket or VideoLiker document when the liker is an anonymous user" do
      @liker1.user_type = User::USER_TYPE[:anonymous]
      expect{@video.like!(@liker1)}.not_to change(VideoLikerBucket, :count)
    end
  end

end
