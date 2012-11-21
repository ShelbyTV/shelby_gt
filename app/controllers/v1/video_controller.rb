class V1::VideoController < ApplicationController  
  require 'user_manager'
  require 'api_clients/vimeo_client'
  require 'api_clients/youtube_client'
  require 'api_clients/dailymotion_client'
  
  before_filter :user_authenticated?, :except => [:show, :find_or_create, :search]

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
        @url = params.delete(:url)
        if @url and @video = GT::VideoManager.get_or_create_videos_for_url(@url)[:videos][0]
          @status = 200
        else
          render_error(404, "could not find video")
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
        @video_ids = video_ids_on_roll(user.watch_later_roll.id)
      else
        @video_ids = []
      end

      @status = 200
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
    return render_error(404, "could not find video with id #{params[:id]}") unless @video
    @video.first_unplayable_at = Time.now unless @video.first_unplayable_at
    @video.last_unplayable_at = Time.now
    @video.save
    
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
    @provider = params.delete(:provider)
    @query = params.delete(:q)
    
    limit = params[:limit] ? params[:limit] : 10
    page = params[:page] ? params[:page] : 1

    return render_error(404, "need to specify both provider and query search term") unless @provider and @query and @query != ""
    
    valid_providers = ["vimeo","youtube","dailymotion"]
    return render_error(404, "need to specify a supported provider") unless valid_providers.include? @provider
    
    converted = (params[:converted] and params[:converted] == "false") ? false : true
    opts = {:limit => limit, :page => page, :converted => converted}
    
    # use different client depending on the provider
    @response = case @provider
      when "vimeo"
        APIClients::Vimeo.search(@query, opts)
      when "youtube"
        APIClients::Youtube.search(@query, opts)
      when "dailymotion"
        APIClients::Dailymotion.search(@query, opts)
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

