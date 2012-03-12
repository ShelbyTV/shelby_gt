class V1::VideoController < ApplicationController  

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/:id.json
  # 
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    if @video = Video.find(params[:id])
      @status =  200
    else
      @status, @message = 500, "could not find video"
    end
  end
  
end