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
  
  private
  
    def video_ids_on_roll(roll_id, limit=1000)
      # This stuff works, but it's slower than using distinct
      #Only return the video_id (abbreviated as :b) for the first 1,000 frames
      #frames = Frame.where(:roll_id => roll_id).limit(1000).fields(:b).all
      #return frames.collect { |f| f.video_id }.compact.uniq
      
      # Very nice, but distinct doesn't support limit yet :(
      return Frame.where(:roll_id => roll_id).distinct(:b)
    end
end

