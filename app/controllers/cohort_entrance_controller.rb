class CohortEntranceController < ApplicationController  
  
  def show
    @cohort_entrance = CohortEntrance.find_by_code(params[:id])
    session[:cohort_entrance_id] = @cohort_entrance.id.to_s
    session[:return_url] = Settings::ShelbyAPI.web_root
  end
  
end