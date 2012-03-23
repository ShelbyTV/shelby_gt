class V1::DashboardEntriesController < ApplicationController  

  before_filter :cors_preflight_check, :authenticate_user!
  
  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard.json
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Boolean] include_children if set to true, will not include all goodies, eg roll, frame etc
  def index
    # default params
    @limit = params[:limit] ? params[:limit] : 20
    # put an upper limit on the number of entries returned
    @limit = 20 if @limit.to_i > 20
    
    skip = params[:skip] ? params[:skip] : 0

    # get user
    if params[:user_id]
      unless user = User.find(params[:user_id])
        @status, @message = 404, "could not find that user"
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
        @status, @message = 200, "there are no dashboard entries for this user"
        render 'v1/blank', :status => 200
      end
    else
      @status, @message = 400, "no user info found"
      render 'v1/blank', :status => 400
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
    if @dashboard_entry = DashboardEntry.find(id)
      begin 
        @status = 200 if @dashboard_entry.update_attributes!(params)
        Rails.logger.info(@dashboard_entry.inspect)
      rescue => e
        @status, @message = 400, "could not update dashboard_entry: #{e}"
        render 'v1/blank', :status => @status
      end
    else
      @status, @message = 400, "could not find that dashboard_entry"
      render 'v1/blank', :status => @status
    end    
  end

end
