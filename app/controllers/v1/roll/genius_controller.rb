require 'set'
require 'video_manager'
require 'framer'

class V1::Roll::GeniusController < ApplicationController
  before_filter :set_current_user
 
  ##
  # Create and return a genius roll from an array of video URLs
  # 
  # [POST] /v1/roll/genius/create
  # 
  # @param [Required, String] search String containing original query
  # @param [Required, String] urls String containing JSON-encoded array of video URLs
  def create
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['genius']['create']) do
      unless params.include?(:urls) and params.include?(:search)
        return render_error(404, "search and urls are both required parameters")
      end

      begin
        urls = ActiveSupport::JSON.decode(params[:urls])
      rescue
        return render_error(404, "unabled to decode urls parameter: invalid JSON")
      end
 
      unless urls
        return render_error(404, "decoded urls parameter was undefined")
      end

      unless urls.kind_of?(Array)
         return render_error(404, "decoded urls parameter was not an array")
      end

      unless !urls.empty?
        return render_error(404, "decoded urls parameter resulted in an empty array")
      end

      vidManagerResults = urls.map { |u| GT::VideoManager.get_or_create_videos_for_url(u) }
      vidManagerVideoArrays = vidManagerResults.map { |r| r[:videos] }
      searchVids = vidManagerVideoArrays.map { |v| v[0] }.compact.uniq
      searchVidIds = searchVids.map { |s| s._id }
      recs = searchVids.map { |s| s.recs.flatten }.flatten.compact
      
      recIdToScoreHash = Hash.new 
      recs.each do |rec|
        recId = rec.recommended_video_id
        recIdToScoreHash[recId] = rec.score + recIdToScoreHash.fetch(recId, 0)
      end

      recIdsSortedArray = recIdToScoreHash.sort { |a,b| b[1] <=> a[1] }.map { |r| r[0] }  

      finalVidIds = combineSearchAndRecVidIds(searchVidIds, recIdsSortedArray, 100)

      @roll = ::Roll.new(:title => "GENIUS: " + params[:search])
      @roll.genius = true
      @roll.roll_type = ::Roll::TYPES[:genius]
      @roll.creator = current_user

      count = 0
      finalVidIds.reverse.each do |videoId|
        frame_options = { :roll => @roll }
        frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_genius_frame]
        frame_options[:video_id] = videoId
        frame_options[:order] = (finalVidIds.size - count) * 100
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

private

  def skipVidsAlreadyAdded(cur, vidIds, finalVidIds)
    cur += 1 while (cur < vidIds.size and finalVidIds.include?(vidIds[cur]))
    return cur
  end

  def checkAndAppendVid!(cur, vidIds, finalVidIds, maxVids)
    if (finalVidIds.size < maxVids and cur < vidIds.size and !finalVidIds.include?(vidIds[cur]))
      finalVidIds.append(vidIds[cur])
    end
    return (cur += 1)
  end

  # this is just an initial simple algorith for combining the item based
  # recommendations we have with YouTube search results. in the future, we'd
  # ideally be intelligently combining videos from several 'signal' sources
  def combineSearchAndRecVidIds(searchVidIds, recIdsSortedArray, maxVids)
  
    r = s = 0
    finalVidIds = []

    while r < recIdsSortedArray.size or s < searchVidIds.size do

      # make sure we add at least one search vid per loop if possible
      s = skipVidsAlreadyAdded(s, searchVidIds, finalVidIds)
      s = checkAndAppendVid!(s, searchVidIds, finalVidIds, maxVids)

      # add 2 recommended vids afterward if next 2 recs are eligible
      r = checkAndAppendVid!(r, recIdsSortedArray, finalVidIds, maxVids)
      r = checkAndAppendVid!(r, recIdsSortedArray, finalVidIds, maxVids)

      # break out early if we've already got enough vids
      break if finalVidIds.size >= maxVids

    end

    return finalVidIds

  end

protected

  def set_current_user
    @current_user = User.find(oauth.identity) if oauth.authenticated?
  end
 
end
