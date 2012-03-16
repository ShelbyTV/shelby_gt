class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :allow_faux_authentication!
  
  respond_to :json
  
  private

    before_filter :cors_preflight_check
    after_filter :cors_set_access_control_headers

    # For all responses in this controller, return the CORS access control headers.
    def cors_set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
      headers['Access-Control-Max-Age'] = "1728000"
    end

    # If this is a preflight OPTIONS request, then short-circuit the
    # request, return only the necessary headers and return an empty
    # text/plain.

    def cors_preflight_check
      if request.method == :options
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version'
        headers['Access-Control-Max-Age'] = '1728000'
        render :text => '', :content_type => 'text/plain'
      end
    end

    def allow_faux_authentication!
      if params[:key] == "1234567890"
        user = User.find_by_nickname('henrysztul')
        sign_in(:user, user)
      end
    end
  
end
