class VideoLikerBucket
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::VideoLiker

  # The video host (ie YouTube, Vimeo, &c.)
  key :provider_name, String, :abbr => :a
  # The unique id used by the host to identify the video
  key :provider_id, String, :abbr => :b

  # 0-based index in the sequence of buckets for a given video
  key :sequence, Integer, :abbr => :c, :default => 0

  many :likers, :class_name => "VideoLiker"
end