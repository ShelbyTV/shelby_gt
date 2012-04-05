class V1::DashboardEntriesController < ApplicationController  

  before_filter :authenticate_user!
  
  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Boolean] include_children if set to true, will not include all goodies, eg roll, frame etc
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit] : 20
      # put an upper limit on the number of entries returned
      @limit = 20 if @limit.to_i > 20
    
      skip = params[:skip] ? params[:skip] : 0

      # get user
      if params[:user_id]
        unless user = User.find(params[:user_id])
          render_error(404, "could not find that user")
        end
      elsif user_signed_in?
        user = current_user
      end
    
      # get and render dashboard entries
      if user
        @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id).all
        @include_children = params[:include_children] != "false" ? true : false
        # return status
        if !@entries.empty?
          @status = 200
        else
          render_error(200, "there are no dashboard entries for this user")
        end
      else
        render_error(404, "no user info found")
      end    
    end
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
      id = params.delete(:id)
      if @dashboard_entry = DashboardEntry.find(id)
        begin 
          @status = 200 if @dashboard_entry.update_attributes!(params)
          Rails.logger.info(@dashboard_entry.inspect)
        rescue => e
          render_error(404, "could not update dashboard_entry: #{e}")
        end
      else
        render_error(404, "could not find that dashboard_entry")
      end    
    end
  end

end
