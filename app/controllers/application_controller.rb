class ApplicationController < ActionController::Base
  protect_from_forgery
  
  respond_to :json
  
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

  private    
    
    # === These headers are set to allow cross site access and cookies to be sent via ajax
    # - see: http://www.tsheffler.com/blog/?p=428 and
    #         https://developer.mozilla.org/En/Server-Side_Access_Control
    #
    #TODO: When we go live only allow cs_key in staging env    
    def set_access_control_headers
      if params[:cs_key] == Settings::ShelbyAPI.cross_site_key
        headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
      else
        headers['Access-Control-Allow-Origin'] = Settings::ShelbyAPI.allow_origin
      end
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version, X-CSRF-Token'
    end
    
    def allow_faux_authentication!
      if params[:key] == "1234567890"
        user = User.find_by_nickname('onshelby')
        sign_in(:user, user)
      end
    end
      
end
