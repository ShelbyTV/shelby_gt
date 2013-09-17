require 'user_manager'

class V1::VideoController < ApplicationController
  require 'user_manager'
  require 'utils/search_combiner'
  require 'api_clients/vimeo_client'
  require 'api_clients/youtube_client'
  require 'api_clients/dailymotion_client'
  require 'api_clients/webscraper_client'

  before_filter :user_authenticated?, :except => [:show, :find_or_create, :search, :fix_if_necessary, :watched]

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/:id
  #
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['show']) do
      if @video = Video.find(params[:id])
        @status =  200
      else
        render_error(404, "could not video with id #{params[:id]}")
      end
    end
  end

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/find_or_create
  #
  # @param [Optional, String] url the url of the video
  # @param [Required, String] provider_name The provider of the video
  # @param [Required, String] provider_id The id of the video
  def find_or_create
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['find']) do
      @provider_name = params.delete(:provider_name)
      @provider_id = params.delete(:provider_id)

      return render_error(404, "need to specify both provider_name and provider_id") unless @provider_name and @provider_id
      if @video = Video.where(:provider_name => @provider_name, :provider_id => @provider_id).first
        @status = 200
      else
        @url = params.delete(:url) || GT::UrlHelper.generate_url_from_provider_info(@provider_name, @provider_id)
        if @url and @video = GT::VideoManager.get_or_create_videos_for_url(@url)[:videos]
          @video = @video.first
          @status = 200
        else
          render_error(404, "could not find video we support")
        end
      end
    end
  end

  ##
  # Returns an index of all viewed videos (with only IDs)
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/video/viewed
  #
  def viewed
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['viewed']) do
      if user = current_user
        # some old users have slipped thru the cracks and are missing rolls, fix that before it's an issue
        GT::UserManager.ensure_users_special_rolls(user, true) unless GT::UserManager.user_has_all_special_roll_ids?(user)
        @video_ids = video_ids_on_roll(user.viewed_roll.id)
      else
        @video_ids = []
      end

      @status = 200
    end
  end

  ##
  # Returns an index of all viewed queued (with only IDs)
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/video/queued
  #
  def queued
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['queued']) do
      if user = current_user
        # some old users have slipped thru the cracks and are missing rolls, fix that before it's an issue
        GT::UserManager.ensure_users_special_rolls(user, true) unless GT::UserManager.user_has_all_special_roll_ids?(user)
        @video_ids = video_ids_on_roll(user.watch_later_roll.id)
      else
        @video_ids = []
      end

      @status = 200
    end
  end

  ##
  # For logged in user, update their viewed_roll and view_count on Video (once per 24 hours per user)
  # For non-logged in user, update their view_count on Video.
  #   AUTHENTICATION OPTIONAL
  #
  # [POST] /v1/video/:id/watched
  #
  # @param [Required, String] id The id of the video
  # @param [Optional, String] start_time The start_time of the current watch span (ie. adjusts to last reported end_time)
  # @param [Optional, String] end_time The end_time of the current watch span (continually updates with progress)
  # @param [Optional, String] complete Set this param iff the viewer finished the video (and do not set <start|end>_time)
  def watched
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['watched']) do
      if @video = Video.find(params[:video_id])
        @status = 200

        # some old users have slipped thru the cracks and are missing rolls, fix that before it's an issue
        GT::UserManager.ensure_users_special_rolls(current_user, true) unless GT::UserManager.user_has_all_special_roll_ids?(current_user) if user_signed_in?

        # conditionally count this as a view (once per 24 hours per user)
        view_recorded = @video.view!(current_user)
        @video.reload # to update view_count

        render 'show'
      else
        render_error(404, "could not find video")
      end
    end
  end

  ##
  # Marks the given video as unplayable as of now
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/video/:video_id/unplayable
  #
  def unplayable
    @video = Video.find(params[:video_id])
    return render_error(404, "could not find video with id #{params[:video_id]}") unless @video
    @video.first_unplayable_at = Time.now unless @video.first_unplayable_at
    @video.last_unplayable_at = Time.now
    @video.save

    @status = 200
    render 'show'
  end

  ##
  # If the given video is missing important information (thumbnail, title, description, embed url, etc.)
  # we will fetch the raw video info, update Video and return it.
  #
  # [PUT] /v1/video/:video_id/fix_if_necessary
  #
  # Return the updated video or original if no update was needed
  #
  def fix_if_necessary
    @video = Video.find(params[:video_id])
    return render_error(404, "could not find video with id #{params[:video_id]}") unless @video

    @video = GT::VideoManager.fix_video_if_necessary(@video)

    @status = 200
    render 'show'
  end

  ##
  # Returns videos video a search query param and a search provider
  #
  # [GET] /v1/video/search
  #
  # @param [Required, String] q search query term
  # @param [Required, String] provider where to perform the search, eg vimeo
  # @param [Optional, String] limit number of videos to return, 10 default
  # @param [Optional, String] page page number to return, 1 default
  # @param [Optional, String] converted return result in shelby form if true, default true
  def search
    @provider = params.delete(:provider) || ""
    @query = params.delete(:q)

    limit = params[:limit] ? params[:limit] : 10
    page = params[:page] ? params[:page] : 1

    return render_error(404, "need to specify both provider and query search term") unless @provider and @query and @query != ""

    valid_providers = ["vimeo","youtube","dailymotion","web",""]
    return render_error(404, "need to specify a supported provider") unless valid_providers.include? @provider

    converted = (params[:converted] and params[:converted] == "false") ? false : true
    opts = {:limit => limit, :page => page, :converted => converted}

    begin
      # use different client depending on the provider
      @response = case @provider
        when ""
          Search::Combiner.get_videos_and_combine(@query, opts)
        when "vimeo"
          APIClients::Vimeo.search(@query, opts)
        when "youtube"
          APIClients::Youtube.search(@query, opts)
        when "dailymotion"
          APIClients::Dailymotion.search(@query, opts)
        when "web"
          APIClients::WebScraper.get(@query, opts)
        end
    rescue => e
      return render_error(404, "Error while searching: #{e}")
    end


    if (@response and @response[:status] == "ok")
      @status = 200
    else
      render_error(404, "could not find any video or an error occured")
    end
  end

  private

    def video_ids_on_roll(roll_id, limit=1000)
      # This stuff works, but it's slower than using distinct
      #Only return the video_id (abbreviated as :b) for the first 1,000 frames
      #frames = Frame.where(:roll_id => roll_id).limit(1000).fields(:b).all
      #return frames.collect { |f| f.video_id }.compact.uniq

      # Since distinct doesn't support limit, we impose some artificial limit via time to keep the query reasonable
      video_ids = Frame.where(:roll_id => roll_id, :id => {"$gt" => BSON::ObjectId.from_time(6.months.ago)}).distinct(:b)
      # and then limit the results array
      return video_ids[0..limit]
    end
end

