require 'recommendation_manager'

class V1::RecommendationController < ApplicationController

  before_filter :user_authenticated?

  ####################################
  # Returns a set of dashboard entries containing recommended videos for the user
  # Returns 200 if successful
  #
  # @param [Optional, String] sources A comma separated list of recommendation sources to use to find recommendations
  #   the values should correspond to the dashboard entry types/actions of the recommendations that will be created;
  #   by default will look for video graph recommendations and mortar recommendations
  #
  # [GET] /v1/user/:id/recommendations
  def index_for_user
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['recommendations']) do
      if params[:user_id] == current_user.id.to_s
        # A regular user can only view his/her own recommendations
        @user = current_user
      elsif current_user.is_admin
        # admin users can view anyone's recommendations
        unless @user = User.where(:id => params[:user_id]).first
          return render_error(404, "could not find that user")
        end
      else
        return render_error(401, "unauthorized")
      end

      if params[:sources]
        sources = params[:sources].split(",").map {|source_string| source_string.to_i}.select do |source|
          [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:mortar_recommendation], DashboardEntry::ENTRY_TYPE[:channel_recommendation]].include? source
        end
      else
        sources = [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:mortar_recommendation]]
      end
      recs = []

      scan_limit = params[:scan_limit] ? params[:scan_limit].to_i : 10
      limit = params[:limit] ? params[:limit].to_i : 3
      min_score = params[:min_score] ? params[:min_score].to_f : 100.0

      rec_manager = GT::RecommendationManager.new(@user)

      if sources.include? DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        # get some video graph recommendations
        video_graph_recommendations = rec_manager.get_video_graph_recs_for_user(scan_limit, limit, min_score)
        video_graph_recommendations.each do |rec|
          # remap the name of the src key so that we can process all the recommendations together
          rec[:src_id] = rec.delete(:src_frame_id)
          rec[:action] = DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        end
        recs.concat(video_graph_recommendations)
      end

      if sources.include? DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        # get at least 3 mortar recs, but more if there weren't as many video graph recs as we wanted
        num_mortar_recommendations = 3 + (limit - recs.count)
        mortar_recommendations = rec_manager.get_mortar_recs_for_user(num_mortar_recommendations)
        recs.concat(mortar_recommendations)
      end

      if sources.include? DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        channel_recommendations = rec_manager.get_channel_recs_for_user(Settings::Channels.featured_channel_user_id, 3)
        recs.concat(channel_recommendations)
      end

      @results = []
      # wrap the recommended videos in 'phantom' frames and dbentries that are not persisted to the db
      recs.each do |rec|
        res = GT::RecommendationManager.create_recommendation_dbentry(
          @user,
          rec[:recommended_video_id],
          rec[:action],
          {
            :persist => false,
            :src_id => rec[:src_id]
          }
        )
        if res
          result_struct = OpenStruct.new
          result_struct.dashboard_entry = res[:dashboard_entry]
          result_struct.frame = res[:frame]
          @results << result_struct
        end
      end

      @results.shuffle!

      @include_frame_children = true
      @status = 200
    end
  end
end
