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
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testdeepfiles/rant.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      vids = GT::VideoManager.get_or_create_videos_for_url(@urlhaslink, false, nil, true, true)
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
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testdeepfiles/google.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      vids = GT::VideoManager.get_or_create_videos_for_url(@urlnolink, false, nil, true, true)
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
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return(nil)
        GT::UrlHelper.stub( :resolve_url ).with(@short_url, false, nil).and_return( @url1 )
        
        GT::UrlVideoDetector.stub( :examine_url_for_video ).with( @url1, false, nil ).and_return([
          {:embedly_hash => { 'url' => "something" }}
          ])
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with("something").and_return({:provider_name=>@v.provider_name, :provider_id=>@v.provider_id})
        
        GT::VideoManager.get_or_create_videos_for_url(@short_url)[:videos].size.should == 1
      end
      
      it "should handle multiple video hash return" do
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@short_url).and_return(nil)
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return(nil)
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
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return(nil)
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
        GT::UrlHelper.stub( :parse_url_for_provider_info ).with(@url1).and_return(nil)
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

  
end
