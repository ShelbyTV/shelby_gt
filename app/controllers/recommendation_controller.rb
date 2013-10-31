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
      if params[:limits]
        limits = params[:limits].split(",").map {|limit| limit.to_i }
      else
        limits = Array.new(sources.length) { 3 }
      end
      recs = []

      rec_manager_options = {}
      rec_manager_options[:excluded_video_ids] = params[:excluded_video_ids].split(",") if params[:excluded_video_ids]
      rec_manager = GT::RecommendationManager.new(@user, rec_manager_options)
      rec_options = {
        :limits => limits,
        :sources => sources
      }
      if (sources.include?(DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]))
        if params[:scan_limit]
          rec_options[:video_graph_entries_to_scan] = params[:scan_limit].to_i
        end
        if params[:min_score]
          rec_options[:video_graph_min_score] = params[:min_score].to_f
        end
      end
      recs = rec_manager.get_recs_for_user(rec_options)

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
