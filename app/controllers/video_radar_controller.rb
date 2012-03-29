class VideoRadarController < ApplicationController  
  before_filter :user_signed_in?, :except => [:boot]
  
  def boot
    params[:chrome_extension] ? @use_case = "extension" : @use_case = "bookmarklet"
  end
  
  def load
    params[:chrome_extension] ? @use_case = "extension" : @use_case = "bookmarklet"
  end
  
end