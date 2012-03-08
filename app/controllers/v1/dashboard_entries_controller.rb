class V1::DashboardEntriesController < ApplicationController  

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard.json
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return (default/max 50)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Boolean] include_children Include the referenced objects
  def index
    # default params
    params[:limit] ||= 50
    params[:skip] ||= 0
    # max number of entries returned
    params[:limit] = 50 if params[:limit] > 50

    # get user
    if params[:user_id]
      @status, @message = 500, "could not find that user" unless user = User.find(params[:user_id])
    elsif user_signed_in?
      user = current_user
    else
      @status, @message = 500, "no user info found, try again"
    end
    
    if user
      # get and structure dashboard_entries
      unless params[:quiet] == false
        @entries = [];
        DashboardEntry.limit(params[:limit]).skip(params[:skip]).where(:user_id => user.id).all.each do |entry|
          @entries << {   :roll => entry.roll, 
                          :frame => entry.frame, 
                          :video => entry.video, 
                          :conversation => entry.conversation, 
                          :user => entry.user }
        end
      else
        @entries = DashboardEntry.limit(params[:limit]).skip(params[:skip]).where(:user_id => user.id).all
      end
      
      # return status
      if !@entries.empty?
        @status = 200
      else
        @status, @message = 500, "error retrieving dashboard entries"
      end
      
    end    
  end
  
  ##
  # Updates and returns one dashboard entry, with the given parameters.
  #
  # [PUT] v1/dashboard/:id.json
  # 
  # @param [Required, String] id The id of the dashboard entry
  def update
    id = params.delete(:id)
    @dashboard_entry = DashboardEntry.find(id)
    if @dashboard_entry and @dashboard_entry.update_attributes(params)
      @status = 200
    else
      @status = 500
      @message = @dashboard_entry ? "could not update dashboard_entry" : "could not find that dashboard_entry"
    end    
  end

end
