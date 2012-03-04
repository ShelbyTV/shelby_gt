class V1::VideoController < ApplicationController  

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/:id.json
  # 
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    if @video = Video.find(id)
      @status =  "ok"
    else
      @status, @message = "error", "could not find video"
    end
  end
  
end