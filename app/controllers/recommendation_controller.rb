require 'recommendation_manager'

class V1::RecommendationController < ApplicationController
  def index_for_user
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['recommendations']) do
      if params[:user_id] == current_user.id.to_s
        # A regular user can only view his/her own recommendations
        @user = current_user
      elsif current_user.is_admin
        # admin users can view anyone's stats
        unless @user = User.where(:id => params[:user_id]).first
          return render_error(404, "could not find that user")
        end
      else
        return render_error(401, "unauthorized")
      end

      limit = params[:limit] ? params[:limit].to_i : 1
      min_score = params[:min_score] ? params[:min_score].to_f : 100.0

      recommended_video_ids = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, 10, limit, min_score)

      @videos = Video.find(recommended_video_ids)

      @status = 200
    end
  end
end
