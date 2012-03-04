class V1::DashboardEntriesController < ApplicationController  

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard.json
  # 
  # @param [Optional, Integer] limit The number of entries to return
  # @param [Optional, Integer] offset The number of offset to return
  # @param [Optional, Boolean] include_children Include the referenced objects
  #
  # @todo return error if id not present w/ params.has_key?(:id)  
  # @todo FIGURE THIS OUT. BUILD IT.
  def index
    # defaults
    params[:limit] ||= 20
    params[:offset] ||= 0
    @dashboad_entries = [];
    DashboardEntry.limit(params[:limit]).skip(params[:offset]).find_each.each do |entry|
      @dashboad_entries << {  :roll => entry.roll, 
                    :frame => entry.frame, 
                    :video => entry.video, 
                    :conversation => entry.conversation, 
                    :user => entry.user
                  }
    end
    
  end
  
  ##
  # Updates and returns one dashboard entry, with the given parameters.
  #
  # [PUT] v1/dashboard/:id.json
  # 
  # @param [Required, String] id The id of the dashboard entry
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @dashboard_entry = DashboardEntry.find(params[:id])
  end

end
