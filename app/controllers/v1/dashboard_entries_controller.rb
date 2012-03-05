class V1::DashboardEntriesController < ApplicationController  

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard.json
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return
  # @param [Optional, Integer] offset The number of offset to return
  # @param [Optional, Boolean] include_children Include the referenced objects
  def index
    # default params
    params[:limit] ||= 20
    params[:offset] ||= 0

    # get user
    if params[:user_id]
      @status, @message = 500, "could not find that user" unless user = User.find(params[:user_id])
    elsif user_signed_in?
      user_id = current_user
    else
      @status, @message = 500, "no user info found, try again"
    end
    
    # get and structure dashboard_entries
    @dashboard_entries = [];
    if params[:include_children]
      DashboardEntry.where(:user_id => user.id).limit(params[:limit]).skip(params[:offset]).find_each.each do |entry|
        @dashboad_entries << {  :roll => entry.roll, 
                                :frame => entry.frame, 
                                :video => entry.video, 
                                :conversation => entry.conversation, 
                                :user => entry.user
                              }
      end
    else
      @dashboard_entries = DashboardEntry.limit(params[:limit]).skip(params[:offset])
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
