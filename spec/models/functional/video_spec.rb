require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Video do
  before(:each) do
    @video = Video.new
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

  context "validations" do
    before(:each) do
      @video = Factory.create(:video)
    end

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
      @video = Factory.create(:video, :title => 'Title with spaces')
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
end
