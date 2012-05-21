class Video
  include MongoMapper::Document
  safe

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Video

  plugin MongoMapper::Plugins::IdentityMap

  # A video may be references by many frames
  many :frames, :foreign_key => :b

  # The video host (ie YouTube, Vimeo, &c.)
  key :provider_name, String, :abbr => :a
  # The unique id used by the host to identify the video
  key :provider_id, String, :abbr => :b

  # Metadata from the host...
  key :title, String, :abbr => :c
  key :name, String, :abbr => :d
  key :description, String, :abbr => :e
  key :duration, String, :abbr => :f
  key :author, String, :abbr => :g
  key :video_height, String, :abbr => :h
  key :video_width, String, :abbr => :i
  key :thumbnail_url, String, :abbr => :j
  key :thumbnail_height, String, :abbr => :k
  key :thumbnail_width, String, :abbr => :l
  key :tags, Array, :typecast => 'String', :abbr => :m
  key :categories, Array, :typecast => 'String', :abbr => :n

  key :source_url, String, :abbr => :o
  key :embed_url, String, :abbr => :p
  
  # Each time a new view is counted (see Frame#view!) we increment this and frame.view_count
  key :view_count, Integer, :abbr => :q, :default => 0
  
  # Reserved for item share based filtering edges
  key :recommendations, Array, :abbr => :r
  
  # mongo has a unique key on these as well
  validates_uniqueness_of :provider_id, :scope => :provider_name

  #nothing needs to be mass-assigned
  attr_accessible
  
  def created_at() self.id.generation_time; end
end
