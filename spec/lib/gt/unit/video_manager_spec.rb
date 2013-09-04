require 'spec_helper'

require 'video_manager'
require 'url_video_detector'

# UNIT test
# This doesn't need to be tested w/ EventMachine or Memcache, since those aren't use directly and are thus tested elsewhere
describe GT::VideoManager do
  before(:all) do
    @short_url = "http://danspinosa.com/xyz"
    @url1 = "http://danspinosa.com/watch/xyz1234/this-is-the-name"
    @v = Video.new
    @v.provider_name = "pro1"
    @v.provider_id = "330033"
    @v.save


    @deep_url = "http://www.youtube.com/embed/lMBMcMf85ow?version=3&rel=1&fs=1&showsearch=0&showinfo=1&iv_load_policy=1&wmode=transparent"
    @dl = DeeplinkCache.new
    @dl.url = @deep_url
    @dl.videos = [@v[:_id]]
    @dl.save

    @urlhaslink = "http://www.thisurlhaslink.com/hello"
    @urlnolink = "http://www.thisurlnolinkk.com/hello"


  end

  context "get_deep_url" do
    it "should find cached deep" do
      vids = GT::VideoManager.get_or_create_videos_for_url(@deep_url, false, nil, true, true)
      vids.should == {:videos => [@v], :from_deep => true}
    end

    it "should find deep" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/rant.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      vids = GT::VideoManager.get_or_create_videos_for_url(@urlhaslink, false, nil, false, true)
      vids[:videos].size.should == 1
      vids[:from_deep].should == true
    end

    it "should be cached" do
      cached = DeeplinkCache.where(:url => @urlhaslink).first
      cached[:url].should == @urlhaslink
    end

    it "should find nothing" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/google.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      vids = GT::VideoManager.get_or_create_videos_for_url(@urlnolink, false, nil, false, true)
      vids.should == {:videos => [], :from_deep =>false}
    end

    it "the nothing deep should be cached" do
      cached = DeeplinkCache.where(:url => @urlnolink).first
      cached[:url].should == @urlnolink
      cached[:videos].should == []
    end



  end

  context "get_or_create_videos_for_url" do

    it "should return [] with crappy url" do
      GT::VideoManager.get_or_create_videos_for_url(nil).should == {:videos => [], :from_deep => false}
      GT::VideoManager.get_or_create_videos_for_url("dan").should == {:videos => [], :from_deep => false}
      GT::VideoManager.get_or_create_videos_for_url("http://4sq.com/xyz").should == {:videos => [], :from_deep => false}
    end

    it "should find Video already in DB" do
      GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

      GT::VideoManager.get_or_create_videos_for_url(@url1).should == {:videos => [@v], :from_deep => false}
    end

    it "should resolve shortlink" do
      GT::UrlHelper.should_receive( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

      GT::VideoManager.get_or_create_videos_for_url(@short_url).should == {:videos => [], :from_deep => false}
    end

    it "should not resolve shortlink is should_resolve_url==false" do
      GT::UrlHelper.should_not_receive( :resolve_url )

      GT::VideoManager.get_or_create_videos_for_url(@short_url, false, nil, false).should == {:videos => [], :from_deep => false}
    end

    it "should find Video already in DB after resolving shortlink" do
      GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
      GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )
      GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

      GT::VideoManager.get_or_create_videos_for_url(@short_url).should == {:videos => [@v], :from_deep => false}
    end

    context "reaching out to external service" do

      it "should use an external service to find video if we have nothing in DB" do
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return( [{}] )

        GT::VideoManager.get_or_create_videos_for_url(@short_url).should == {:videos => [], :from_deep => false}
      end

      it "should handle nil return from external service" do
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return( nil )

        GT::VideoManager.get_or_create_videos_for_url(@short_url).should == {:videos => [], :from_deep => false}
      end

      it "should handle single video hash return" do
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with( @url1).and_return({:provider_name => "name", :provider_id => "id"})

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return([
          {:embedly_hash => { 'url' => "something" }}
          ])
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with("something").and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

        GT::VideoManager.get_or_create_videos_for_url(@short_url)[:videos].size.should == 1
      end

      it "should handle multiple video hash return" do
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return({:provider_name=>"name",:provider_id=>"id"})
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return([
          {:embedly_hash => { 'url' => "something" }},
          {:embedly_hash => { 'url' => "something" }},
          {:embedly_hash => { 'url' => "something" }},
          {:embedly_hash => { 'url' => "something" }}
          ])
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with("something").and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

        GT::VideoManager.get_or_create_videos_for_url(@short_url)[:videos].size.should == 4
      end

    end

    context "embed.ly hash" do

      it "should create and persist a Video from an embed.ly hash" do
        h = {
          'provider_name' => 'utewb',
          'title' => 'of the book',
          'name' => 'george',
          'description' => 'just something im testing',
          'author_name' => 'espinosa',
          'height' => '400px',
          'width' => '800px',
          'thumbnail_url' => 'http://thu.mb',
          'thumbnail_height' => '40px',
          'thumbnail_width' => '80px',
          'url' => 'the_url',
          'html' => '-iframe src=\'whatever\' /-'
          }
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return({:provider_name=>"name", :provider_id=>"id"})
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return([
          {:embedly_hash => h}
          ])
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with("the_url").and_return({:provider_name=>"the_provider_name", :provider_id=>"the_provider_id"})

        #should actually create a new video
        vid_count = Video.count
        vids = GT::VideoManager.get_or_create_videos_for_url(@short_url)[:videos]
        Video.count.should == vid_count + 1

        vids.size.should == 1
        v = vids[0]
        v.persisted?.should == true
        v.should_not == @v
        v.provider_name.should == "the_provider_name"
        v.provider_id.should == "the_provider_id"
        v.title.should == h['title']
        v.name.should == h['name']
        v.description.should == h['description']
        v.author.should == h['author_name']
        v.video_height.should == h['height']
        v.video_width.should == h['width']
        v.thumbnail_url.should == h['thumbnail_url']
        v.thumbnail_height.should == h['thumbnail_height']
        v.thumbnail_width.should == h['thumbnail_width']
        v.source_url.should == h['url']
        v.embed_url.should == h['html']
      end

      it "should return Video from DB if embed.ly hash references one in there" do
        h = { 'url' => 'a_new_url' }
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return({:provider_name=>"name", :provider_id=>"id"})
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )

        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return([
          {:embedly_hash => h}
          ])
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with("a_new_url").and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

        vid_count = Video.count
        vids = GT::VideoManager.get_or_create_videos_for_url(@short_url)[:videos]

        #should find the Video in our DB, not create one
        Video.count.should == vid_count
        vids.size.should == 1
        vids[0].should == @v
      end

      it "should fix a Video when necessary" do
        h = {
          'provider_name' => 'utewb',
          'title' => 'of the book',
          'name' => 'george',
          'description' => 'just something im testing',
          'author_name' => 'espinosa',
          'height' => '400px',
          'width' => '800px',
          'thumbnail_url' => 'http://thu.mb',
          'thumbnail_height' => '40px',
          'thumbnail_width' => '80px',
          'url' => 'the_url',
          'html' => '-iframe src=\'whatever\' /-'
          }
        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, false ).and_return([{:embedly_hash => h}])

        # A vidoe missing some important information
        video = Video.new
        video.provider_name = "dan"
        video.provider_id = "33"
        video.source_url = @url1
        video.save

        #should not actually create a new video
        vid_count = Video.count
        updated_vid = GT::VideoManager.fix_video_if_necessary(video)
        Video.count.should == vid_count

        #some things stay the same
        updated_vid.id.should == video.id
        updated_vid.provider_name.should == video.provider_name
        updated_vid.provider_id.should == video.provider_id
        updated_vid.source_url.should == video.source_url

        #some things are updated
        updated_vid.persisted?.should == true
        updated_vid.title.should == h['title']
        updated_vid.name.should == h['name']
        updated_vid.description.should == h['description']
        updated_vid.author.should == h['author_name']
        updated_vid.video_height.should == h['height']
        updated_vid.video_width.should == h['width']
        updated_vid.thumbnail_url.should == h['thumbnail_url']
        updated_vid.thumbnail_height.should == h['thumbnail_height']
        updated_vid.thumbnail_width.should == h['thumbnail_width']
        updated_vid.embed_url.should == h['html']
      end

    end

    context "mongo failure due to timing issue" do
      before(:each) do
        @h = {
          'provider_name' => 'utewb',
          'title' => 'of the book',
          'name' => 'george',
          'description' => 'just something im testing',
          'author_name' => 'espinosa',
          'height' => '400px',
          'width' => '800px',
          'thumbnail_url' => 'http://thu.mb',
          'thumbnail_height' => '40px',
          'thumbnail_width' => '80px',
          'url' => 'the_url',
          'html' => '-iframe src=\'whatever\' /-'
        }
      end

      it "should return correct Video if it gets created after checking for existance but before trying to save" do
        # In this scenario, GT::VideoManager.find_or_create_video_for_embedly_hash looks for Video, finds nothing.
        #
        # So it creates that Video and saved, but mongo raises Mongo::OperationFailure b/c that Video has been created by
        # another Arnold in the time it took me to create and try to save.
        #
        # --> In this case, i should return the Video that was created

        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@h['url']).and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})

        #on first Video.where(...).first need to return NIL
        #on second Video.where(...).first needs to return @v
        timing_issue_video_class = mock_model("Video")
        timing_issue_video_class.stub(:first).and_return(nil, @v)
        Video.stub(:where).and_return(timing_issue_video_class)

        #then on v.save need to throw Mongo::OperationFailure
        exception_throwing_vid = double("vid", :provider_name= => nil, :provider_id= => nil, :title= =>nil, :name= => nil, :description= => nil, :author= => nil, :video_height= => nil, :video_width= => nil, :thumbnail_url= => nil, :thumbnail_height= => nil, :thumbnail_width= => nil, :source_url= => nil, :embed_url= => nil)
        exception_throwing_vid.should_receive(:save).and_raise(Mongo::OperationFailure)
        Video.should_receive(:new).and_return(exception_throwing_vid)

        v = nil
        lambda {
          v = GT::VideoManager.send(:find_or_create_video_for_embedly_hash, @h).should
        }.should_not raise_error(Mongo::OperationFailure)
        v.should == @v
      end
    end

    context "shelby hash" do
      #TODO when it's implemented
    end

  end

  context "update_video_info" do

    before(:each) do
      @vid = Factory.create(:video)
      @yt_model = double("yt_model", :noembed => false, :state => {:name => "published"})
      yt_parser = double("yt_parser", :parse => @yt_model)
      YouTubeIt::Parser::VideoFeedParser.stub(:new).and_return(yt_parser)
    end

    it "should try to update the video info if it's never been updated" do
      GT::VideoProviderApi.should_receive(:get_video_info).with(@vid.provider_name, @vid.provider_id)

      GT::VideoManager.update_video_info(@vid)
    end

    it "should try to update the video info if it hasn't been updated recently enough" do
      @vid.info_updated_at = 3.hours.ago
      GT::VideoProviderApi.should_receive(:get_video_info).with(@vid.provider_name, @vid.provider_id)

      GT::VideoManager.update_video_info(@vid)
    end

    it "should not try to update the video info if it was updated recently enough" do
      @vid.info_updated_at = 1.hours.ago
      GT::VideoProviderApi.should_not_receive(:get_video_info)

      GT::VideoManager.update_video_info(@vid)
    end

    it "should always try to update the video if cache=false is passed" do
      @vid.info_updated_at = 1.hours.ago
      GT::VideoProviderApi.should_receive(:get_video_info)

      GT::VideoManager.update_video_info(@vid, false)
    end

    it "should set the video to available if a 200 is returned" do
      response = double("response", :code => 200, :body => "")
      GT::VideoProviderApi.stub(:get_video_info).and_return(response)
      @vid.should_not_receive(:save)

      GT::VideoManager.update_video_info(@vid)
      @vid.available.should == true
    end

    it "should set the video to unavailable if a 404 is returned" do
      response = double("response", :code => 404, :body => "")
      GT::VideoProviderApi.stub(:get_video_info).and_return(response)
      @vid.should_receive(:save)

      GT::VideoManager.update_video_info(@vid)
      @vid.available.should == false
    end

    context "youtube specific info" do

      it "should set the video to unavailable if its not embeddable" do
        response = double("response", :code => 200, :body => "")
        GT::VideoProviderApi.stub(:get_video_info).and_return(response)
        @yt_model.should_receive(:noembed).and_return(true)

        @vid.should_receive(:save)

        GT::VideoManager.update_video_info(@vid)
        @vid.available.should == false
      end

      it "should set the video to unavailable if its state is not published" do
        response = double("response", :code => 200, :body => "")
        GT::VideoProviderApi.stub(:get_video_info).and_return(response)
        @yt_model.should_receive(:state).twice.and_return({:name => "restricted"})

        @vid.should_receive(:save)

        GT::VideoManager.update_video_info(@vid)
        @vid.available.should == false
      end

    end

    context "vimeo specific info" do
      before(:each) do
        @vid.provider_name = "vimeo"
        @vid.save
      end

      it "should not do any youtube type processing" do
        response = double("response", :code => 200, :body => "")
        GT::VideoProviderApi.stub(:get_video_info).and_return(response)
        YouTubeIt::Parser::VideoFeedParser.should_not_receive(:new)

        @vid.should_not_receive(:save)

        GT::VideoManager.update_video_info(@vid)
        @vid.available.should == true
      end

    end

    it "should do nothing if neither 200 nor 404 is returned" do
      response = double("response", :code => 500, :body => "")
      GT::VideoProviderApi.stub(:get_video_info).and_return(response)
      @vid.should_not_receive(:save)

      lambda {
        GT::VideoManager.update_video_info(@vid)
      }.should_not change { @vid.available }
    end

  end

end
