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

      scan_limit = params[:scan_limit] ? params[:scan_limit].to_i : 10
      limit = params[:limit] ? params[:limit].to_i : 1
      min_score = params[:min_score] ? params[:min_score].to_f : 100.0

      recommendations = GT::RecommendationManager.get_random_video_graph_recs_for_user(@user, scan_limit, limit, min_score)

      @results = []
      # wrap the recommended videos in 'phantom' frames and dbentries that are not persisted to the db
      recommendations.each do |rec|
        src_frame = Frame.find(rec[:src_frame_id])
        res = GT::Framer.create_frame(
          :video_id => rec[:recommended_video_id],
          :dashboard_user_id => @user.id,
          :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
          :dont_persist => true,
          :dashboard_entry_options => {
            :src_frame => src_frame
          }
        )
        if res[:dashboard_entries] and !res[:dashboard_entries].empty? && res[:frame]
          result_struct = OpenStruct.new
          result_struct.dashboard_entry = res[:dashboard_entries].first
          result_struct.frame = res[:frame]
          @results << result_struct
        end
      end

      @include_frame_children = true
      @status = 200
    end
  end
end
