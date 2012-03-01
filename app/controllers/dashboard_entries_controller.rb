class DashboardEntriesController < ApplicationController  

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] /dashboad.[format]?attr_name=attr_val
  # 
  # @param [Optional, Integer] limit The number of entries to return
  # @param [Optional, Integer] limit The number of offset to return
  # @param [Optional, Boolean] include_children Include the referenced objects
  # @param [Optional, Boolean] unread Only get unread entries
  #
  # @todo return error if id not present w/ params.has_key?(:id)  
  # @todo FIGURE THIS OUT. BUILD IT.
  def index
    
  end

  ##
  # Returns one dashboad entry, with the given parameters.
  #
  # [GET] /dashboad.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the dashboad entry
  # @param [Optional, Boolean] include_children Include the referenced objects
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @post = DashboardEntry.find(id)
  end
  
  ##
  # Creates and returns one dashboard entry, with the given parameters.
  #
  # [POST] /dashboard.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one dashboard entry, with the given parameters.
  #
  # [PUT] /dashboard.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the dashboard entry
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @dashboard = DashboardEntry.find(params[:id])
  end
  
  ##
  # Destroys one dashboard entry, returning Success/Failure
  #
  # [DELETE] /dashboard.[format]/:id
  # 
  # @param [Required, String] id The id of the dashboard entry to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @dashboard = DashboardEntry.find(params[:id])
  end

end
