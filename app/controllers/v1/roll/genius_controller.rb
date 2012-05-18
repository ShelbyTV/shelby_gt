require 'video_manager'
require 'framer'

class V1::Roll::GeniusController < ApplicationController  
  
  ##
  # Create and return a genius roll from an array of video URLs
  # 
  # [POST] /v1/roll/genius/create
  # 
  # @param [Required, String] search String containing original query
  # @param [Required, String] urls String containing JSON-encoded array of video URLs
  def create
    # XXX Need Stats -- slightly weird due to nesting
    unless params.include?(:urls) and params.include?(:search)
      return render_error(404, "search and urls are both required parameters")
    end

    @urlsArray = ActiveSupport::JSON.decode(params[:urls])
    unless !@urlsArray.empty?
      return render_error(404, "decoded urls parameter resulted in an empty array")
    end

    @roll = ::Roll.new(:title => "GENIUS: " + params[:search])
    @roll.genius = true
 
    @urlsArray.each do |url|
      frame_options = { :roll => @roll }
      frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_genius_frame]
      frame_options[:video] = GT::VideoManager.get_or_create_videos_for_url(url)[0]
      if frame_options[:video]
        GT::Framer.create_frame(frame_options)
      end
    end
    
    begin
      if @roll.save!
        @status = 200
      end
    rescue => e
      render_error(404, "could not save roll: #{e}")
    end
  end
end
