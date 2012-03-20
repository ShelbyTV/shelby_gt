# Loads up the tumblr yml files used by our test cases
module TumblrData

  def self.with_video_hash() return self.tumblr_hash[:predator_update]["tumblr_status_update"]; end
  def self.with_video_json() return self.with_video_hash.to_json; end
  
  private
    @@tm_hash = false
    
    def self.tumblr_hash
      return @@tm_hash if @@tm_hash
      @@tm_hash = {}
      
      #tumblr post with a link and it's a video
      predator_update = YAML.load( File.read(File.expand_path("../tumblr_post_with_video_link.yml", __FILE__)) )
      @@tm_hash[:predator_update] = predator_update
      
      return @@tm_hash
    end
end