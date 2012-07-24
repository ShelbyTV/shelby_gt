class V1::VideoController < ApplicationController  
  require 'user_manager'
  
  before_filter :user_authenticated?, :only => [:viewed]

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
      @user = current_user

      # might be loading more info than necessary... could possibly specify fields
      @viewed_roll_frames = @user.viewed_roll ? @user.viewed_roll.frames : []
      @videos = @viewed_roll_frames.collect {|x| x.video}
      @videos.compact! if @videos
      @videos.uniq! if @videos

      # limit us to 1000 most recent video IDs returned... hopefully this works with uniq!
      @videos = @videos.first(1000)

      @status = 200
    end
  end  
end

