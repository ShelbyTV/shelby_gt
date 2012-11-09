class CohortEntranceController < ApplicationController  
  
  def show
    if @cohort_entrance = CohortEntrance.find_by_code(params[:id])
      session[:cohort_entrance_id] = @cohort_entrance.id.to_s
      session[:return_url] = Settings::ShelbyAPI.web_root
    else
      redirect_to "#{Settings::ShelbyAPI.web_root}/?access=nos"
    end
  end
  
  # this has very similar funcitonality to the #show action
  # difference: this sends back to a different place + has different view
  # in the future, this might diverge from #show action even further ?
  def show_popup
    if @cohort_entrance = CohortEntrance.find_by_code(params[:id])
      session[:cohort_entrance_id] = @cohort_entrance.id.to_s
      # send to back to whence they came.
      if params[:return_url]
        session[:return_url] = params[:return_url]
      else
        session[:return_url] = Settings::ShelbyAPI.web_root
      end
    else
      redirect_to "#{Settings::ShelbyAPI.web_root}/?access=nos"
    end
  end
  
end