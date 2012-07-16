class CohortEntranceController < ApplicationController  
  
  def show
    if @cohort_entrance = CohortEntrance.find_by_code(params[:id])
      session[:cohort_entrance_id] = @cohort_entrance.id.to_s
      session[:return_url] = Settings::ShelbyAPI.web_root
    else
      redirect_to "#{Settings::ShelbyAPI.web_root}/?access=nos"
    end
  end
  
end