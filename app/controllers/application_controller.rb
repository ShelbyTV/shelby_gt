class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :user_signed_in!
  after_filter :set_access_control_headers, :user_signed_in!
  
  respond_to :json

  def user_signed_in!
    session[:signed_in] = user_signed_in? ? true : false
  end

  def cors_preflight_check
    if params[:cs_key] == Settings::ShelbyAPI.cross_site_key
      headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
    else
      headers['Access-Control-Allow-Origin'] = Settings::ShelbyAPI.allow_origin
    end
    headers['Access-Control-Allow-Methods'] = '*'
    headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version, X-CSRF-Token'
    headers['Access-Control-Allow-Credentials'] = 'true'
    headers['Access-Control-Max-Age'] = '1000'
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
    
    # Overwriting the sign_out redirect path method
    #def after_sign_out_path_for(resource_or_scope)
    #  sign_out_path
    #end
  
end
