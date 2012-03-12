class V1::DashboardEntriesController < ApplicationController  

  before_filter :authenticate_user!, :except => [:index]
  
  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard.json
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return (default/max 50)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Boolean] quiet if set to true, will not include all goodies, eg roll, frame etc
  def index
    # default params
    limit = params[:limit] ? params[:limit] : 20
    #TODO: max number of entries returned
    skip = params[:skip] ? params[:skip] : 0

    # get user
    if params[:user_id]
      @status, @message = 500, "could not find that user" unless user = User.find(params[:user_id])
    elsif user_signed_in?
      user = current_user
    else
      @status, @message = 500, "no user info found, try again"
    end
    
    if user
      @entries = DashboardEntry.limit(limit).skip(skip).sort(:id.desc).where(:user_id => user.id).all
      if params[:quiet] != "true"
        #render simple layout
      else
        #render full layout
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
