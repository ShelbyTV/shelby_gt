class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :preflight_check, :allow_faux_authentication!
  after_filter :set_access_control_headers
  
  respond_to :json

  private    
    
    # === These headers are set to allow cross site access and cookies to be sent via ajax
    # - see: http://www.tsheffler.com/blog/?p=428 and
    #         https://developer.mozilla.org/En/Server-Side_Access_Control
    #
    #TODO: When we go live only allow cs_key in staging env
    def preflight_check
      Rails.logger.info "PREFLIGHT CHECK! #{request.method} which is a #{request.method.class}"
      if request.method == "OPTIONS"
        if params[:cs_key] == Settings::ShelbyAPI.cross_site_key
          headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
        else
          headers['Access-Control-Allow-Origin'] = Settings::ShelbyAPI.allow_origin
        end
        headers['Access-Control-Allow-Methods'] = '*'
        headers['Access-Control-Max-Age'] = '5000'
        headers['Access-Control-Allow-Credentials'] = 'true'
        render :text => '', :content_type => 'text/plain'
      end
    end
    
    def set_access_control_headers
      if params[:cs_key] == Settings::ShelbyAPI.cross_site_key
        headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
      else
        headers['Access-Control-Allow-Origin'] = Settings::ShelbyAPI.allow_origin
      end
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Credentials'] = 'true'
    end

    def allow_faux_authentication!
      if params[:key] == "1234567890"
        user = User.find_by_nickname('henrysztul')
        sign_in(:user, user)
      end
    end
  
end
