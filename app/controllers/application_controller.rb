class ApplicationController < ActionController::Base
  protect_from_forgery
  
  respond_to :json
  
  # Used to DRY things up in the API controllers
  def render_error(code, message)
    @status, @message = code, message
    render 'v1/blank'
  end
  
  # === Unlike the default user_authenticated! helper that ships with devise,
  #  We want to render our json response as well as just the http 401 response
  def user_authenticated?
    unless user_signed_in?
      @status, @message = 401, "you must be authenticated"
      render 'v1/blank', :status => @status
    end
  end
      
end
