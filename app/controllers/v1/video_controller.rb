class V1::VideoController < ApplicationController  

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /v1/video/:id
  # 
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['show']) do
      if params[:id]
        return render_error(404, "please specify a valid id") unless (id = ensure_valid_bson_id(params[:id]))
        if @video = Video.find(id)
          @status =  200
        else
          render_error(404, "could not find video")
        end
      else
        render_error(404, "must specify an id, man.")
      end
    end
  end
  
end