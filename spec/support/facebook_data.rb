# Loads up the twitter yml files used by our test cases
module FacebookData

  def self.with_video_hash() return self.facebook_hash[:predator_update]["facebook_status_update"]; end
  def self.with_video_json() return self.with_video_hash.to_json; end
  
  private
    @@fb_hash = false
    
    def self.facebook_hash
      return @@fb_hash if @@fb_hash
      @@fb_hash = {}
      
      #fb post with a link and it's a video
      predator_update = YAML.load( File.read(File.expand_path("../fb_post_with_video_link.yml", __FILE__)) )
      @@fb_hash[:predator_update] = predator_update
      
      return @@fb_hash
    end
end