# Loads up the twitter yml files used by our test cases
module TwitterData

  def self.no_video_hash() return self.twitter_yaml[:link_no_video]["tweet"]; end
  def self.no_video_json() return self.no_video_hash.to_json; end
  
  private
    @@twt_yaml = false
    
    def self.twitter_yaml
      return @@twt_yaml if @@twt_yaml
      @@twt_yaml = {}
      
      #tweet with a link but it's not to a video
      link_no_video = YAML.load( File.read(File.expand_path("../tweet_no_video_link.yml", __FILE__)) )
      @@twt_yaml[:link_no_video] = link_no_video
      
      return @@twt_yaml
    end
end