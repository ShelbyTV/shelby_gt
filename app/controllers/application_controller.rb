class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :allow_faux_authentication!
  after_filter :set_access_control_headers
  
  respond_to :json
  
  private

   def set_access_control_headers
     headers['Access-Control-Allow-Origin'] = '*'
     headers['Access-Control-Request-Method'] = '*'
   end

    def allow_faux_authentication!
      if params[:key] == "1234567890"
        user = User.find_by_nickname('henrysztul')
        sign_in(:user, user)
      end
    end
  
end
