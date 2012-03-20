class V1::VideoController < ApplicationController  

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/:id
  # 
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    @video = Video.find(params[:id])
    if @video
      @status =  200
    else
      @status, @message = 400, "could not find video"
      render 'v1/blank'
    end
  end
  
end