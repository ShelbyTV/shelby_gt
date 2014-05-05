class Video
  include MongoMapper::Document
  safe

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Video

  before_create :set_video_info_updated_at_now

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

  # Total number of likes - both by upvoters (logged in likers) and logged out likers
  key :like_count, Integer, :abbr => :v, :default => 0

  # whether the video is still available from the provider
  key :available, Boolean, :abbr => :w, :default => true

  # the last time the video info was refreshed from the provider
  key :info_updated_at, Time, :abbr => :x

  # Total number of likers tracked in the video-likers collection for this video
  key :tracked_liker_count, Integer, :abbr => :y, :default => 0

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

  def video_provider_permalink
    case self.provider_name
    when "youtube"
      return "http://www.youtube.com/watch?v=" + self.provider_id
    when "vimeo"
      return "http://vimeo.com/" + self.provider_id
    when "dailymotion"
      return "http://www.dailymotion.com/video/" + self.provider_id
    else #SOL
      return nil
    end
  end

  #------ Viewing

  # Create a Frame with this video on the User's viewed_roll if they haven't viewed this in the last day.
  # Also updates the view_count on this video regardless if user is passed in
  #
  # Returns false if view was recently recorded, otherwise returns this video
  def view!(u)
    raise ArgumentError, "must supply valid User Object or nil" unless u.is_a?(User) or u.nil?

    if u and Frame.roll_includes_video?(u.viewed_roll_id, self.id, 1.day.ago)
      # This Video has been added to the user's viewed_roll in the last 1 day, ignore this view
      return false
    end

    # Always update view counts
    Video.increment(self.id, :q => 1)  # :view_count is :q in Video

    # when a video.reload happens we want to get the real doc that is reloaded, not the cached one.
    MongoMapper::Plugins::IdentityMap.clear if Settings::Video.mm_use_identity_map

    unless u.nil?
      # Create a frame on users viewed_roll with this video
      GT::Framer.create_frame({
        :creator => u,
        :video => self,
        :roll => u.viewed_roll,
        :skip_dashboard_entries => true
      })
    end

    return self
  end

  #------ Like ------

  # increment the like_count and tracked_liker_count of this video
  # record a VideoLiker record for this user and video
  # then reload so that the atomic updates on the db side are reflected in this model
  def like!(liker)
    # increment like_count atomically, abbreviation is :v
    self.increment({:v => 1})
    GT::VideoLikerManager.add_liker_for_video(self, liker) unless liker.user_type == User::USER_TYPE[:anonymous]
    self.reload
  end

  def set_video_info_updated_at_now
    self.info_updated_at = Time.now.utc
  end

end
