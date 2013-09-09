require 'recommendation_manager'

class V1::RecommendationController < ApplicationController
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

      scan_limit = params[:scan_limit] ? params[:scan_limit].to_i : 10
      limit = params[:limit] ? params[:limit].to_i : 3
      min_score = params[:min_score] ? params[:min_score].to_f : 100.0

      # get some video graph recommendations
      video_graph_recommendations = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, scan_limit, limit, min_score)
      video_graph_recommendations.each do |rec|
        # remap the name of the src key so that we can process all the recommendations together
        rec[:src_id] = rec.delete(:src_frame_id)
        rec[:action] = DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      end

      # get at least 3 mortar recs, but more if there weren't as many video graph recs as we wanted
      num_mortar_recommendations = 3 + (limit - video_graph_recommendations.count)
      mortar_recommendations = GT::RecommendationManager.get_mortar_recs_for_user(@user, num_mortar_recommendations)

      @results = []
      recs = video_graph_recommendations + mortar_recommendations
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
