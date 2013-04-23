class V1::DashboardEntriesController < ApplicationController

  before_filter :authenticate_user!, :except => [:short_link]

  ##
  # Returns frames of the videos fo the parameters
  #
  # [GET] v1/dashboard/find_entries_with_video/
  #
  # @param [Required, String] provider_name The name of the provider
  # @param [Required, String] provider_id The id of the provider
  #
  def find_entries_with_video
    provider_name = params.delete(:provider_name)
    provider_id = params.delete(:provider_id)
    return render_error(404, "need to specify both provider_name and provider_id") unless (provider_name and provider_id)
    @status = 200
    @include_frame_children = true
    db_entries = current_user.dashboard_entries.limit(100).all
    frames = Frame.find((db_entries.map {|db_entry| db_entry.frame_id}).compact.uniq)
    videos = Video.find((frames.map {|frame| frame.video_id}).compact.uniq)
    selected_video = videos.select {|video| video.provider_id == provider_id and video.provider_name == provider_name}
    if selected_video.empty?
      @frames = []
      return
    end
    selected_frames = frames.select {|frame| (selected_video[0]).id == frame.video_id}
    @frames = selected_frames
  end

  ##
  # Updates and returns one dashboard entry, with the given parameters.
  #
  # [PUT] v1/dashboard/:id.json
  #
  # @param [Required, String] id The id of the dashboard entry
  #
  #TODO: Do not user update_attributes, instead only allow updating specific attrs
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['update']) do
      if params[:id]
        if @dashboard_entry = DashboardEntry.find(params[:id])
          begin
            @status = 200 if @dashboard_entry.update_attributes!(params)
          rescue => e
            render_error(404, "could not update dashboard_entry: #{e}")
          end
        else
          render_error(404, "could not find dashboard_entry with id #{params[:id]}")
        end
      else
        render_error(404, "must specify an id.")
      end
    end
  end


  ##
  # gets a short link for the given dashboard_entry
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/dashboard/:id/short_link
  #
  # @param [Required, String] id The id of the dashboard entry
  def short_link
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['short_link']) do
      if dbe = DashboardEntry.find(params[:id])
        @status = 200
        @short_link = GT::LinkShortener.get_or_create_shortlinks(dbe, 'email', current_user)
      else
        render_error(404, "could not find dashboard entry")
      end
    end
  end


end
