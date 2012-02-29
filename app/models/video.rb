class Video
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Video

  # A video may be references by many frames
  many :frames, :foreign_key => :b

  # The video host (ie YouTube, Vimeo, &c.)
  key :provider_name, String, :abbr => :a
  # The unique id used by the host to identify the video
  key :privoder_id, String, :abbr => :b

  # Metadata from the host...
  key :title, String, :abbr => :c
  key :description, String, :abbr => :d
  key :duration, String, :abbr => :e
  key :author, String, :abbr => :f
  key :video_height, String, :abbr => :g
  key :video_width, String, :abbr => :h
  key :thumbnail_url, String, :abbr => :i
  key :thumbnail_height, String, :abbr => :j
  key :thumbnail_width, String, :abbr => :k
  key :tags, Array, :typecase => String, :abbr => :l
  key :categories, Array, :typecase => String, :abbr => :m

  #nothing needs to be mass-assigned
  attr_accessible
end
