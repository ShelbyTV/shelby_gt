class Video
  include MongoMapper::Document
  safe

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Video

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
  key :recs, Array, :typecast => 'Recommendation', :abbr => :r
  many :recommendations, :in => :recs
  
  # Maintain the first and the most recent time we noticed this video had playback errors
  key :first_unplayable_at, Time, :abbr => :s
  key :last_unplayable_at, Time, :abbr => :t
  
  # The shortlinks created for each type of share, eg twitter, tumblr, email, facebook
  key :short_links, Hash, :abbr => :u, :default => {}

  # Arnold does a *shit ton* of Video creation, which runs this validation, which turns out to be very expensive 
  # This validations is technically unnecessary because there is a unique index on [provider_id, provider_name] in the database.
  # Additionally: 1) Arnold performs manual validation on Video create. 2) This doesn't even gurantee uniqueness (timing issues)
  # So, we turn this validation off for performance reasons inside of Arnold
  if Settings::Performance.validate_uniqueness_video_provider_name_id
    validates_uniqueness_of :provider_id, :scope => :provider_name
  end

  #nothing needs to be mass-assigned
  attr_accessible
  
  def created_at() self.id.generation_time; end

  def permalink
    title_segment = self.title.downcase.gsub(/\W/,'-').gsub(/"/,"'").squeeze('-').chomp('-')
    "#{Settings::ShelbyAPI.web_root}/video/#{self.provider_name}/#{self.provider_id}/#{title_segment}"
  end

  def video_page_permalink
    # since this is a video, same as regular permalink
    self.permalink
  end

  def subdomain_permalink
    # since the video doesn't belong to any particular shelby subdomain, same as regular permalink
    self.permalink
  end
end
