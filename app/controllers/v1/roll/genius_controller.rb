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

    begin
      @urls = ActiveSupport::JSON.decode(params[:urls])
    rescue
      return render_error(404, "unabled to decode urls parameter: invalid JSON")
    end
 
    unless @urls
      return render_error(404, "decoded urls parameter was undefined")
    end

    unless @urls.kind_of?(Array)
       return render_error(404, "decoded urls parameter was not an array")
    end

    unless !@urls.empty?
      return render_error(404, "decoded urls parameter resulted in an empty array")
    end

    @roll = ::Roll.new(:title => "GENIUS: " + params[:search])
    @roll.genius = true

    @searchVids = []
    @urls.each do |url|
      video = GT::VideoManager.get_or_create_videos_for_url(url)[0][0]
      @searchVids.append(video) if video
    end

    @recsHash = Hash.new
    @searchVids.each do |searchVid|
      searchVid.recs.each do |rec|
        recVideo = Video.find(rec.recommended_video_id)
        if recVideo
          @recsHash[recVideo] = rec.score + @recsHash.fetch(recVideo, 0)
        end
      end if searchVid.recs
    end

    @recsSortedArray = @recsHash.sort { |a,b| b[1] <=> a[1] }
    @finalVids = []

    r = 0
    s = 0
    roughDesiredFinalRollLength = 100

    while r < @recsSortedArray.length or s < @searchVids.length do

      while s < @searchVids.length and @finalVids.include?(@searchVids[s]) do
        s += 1
      end

      if s < @searchVids.length and !@finalVids.include?(@searchVids[s])
        @finalVids.append(@searchVids[s])
      end

      s += 1

      if r < @recsSortedArray.length and !@finalVids.include?(@recsSortedArray[r][0])
        @finalVids.append(@recsSortedArray[r][0])
      end

      r += 1

      if r < @recsSortedArray.length and !@finalVids.include?(@recsSortedArray[r][0])
        @finalVids.append(@recsSortedArray[r][0])
      end

      r += 1

      if @finalVids.length > roughDesiredFinalRollLength
        break
      end
    end

    count = 0
    @finalVids.each do |video|
      frame_options = { :roll => @roll }
      frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_genius_frame]
      frame_options[:video] = video
      frame_options[:order] = (@finalVids.length - count) * 100
      GT::Framer.create_frame(frame_options)
      count += 1
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
