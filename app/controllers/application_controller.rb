class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :debug_cookies_and_session
  after_filter :set_access_control_headers
  
  respond_to :json
  
  def render_error(code, message)
    @status, @message = code, message
    Rails.logger.error "render_error(#{code}, '#{message}')"
    render 'v1/blank', :status => @status
  end
  
  # === Unlike the default user_authenticated! helper that ships with devise,
  #  We want to render our json response as well as just the http 401 response
  def user_authenticated?
    warden.authenticate(:oauth) unless user_signed_in?
    unless user_signed_in?
      @status, @message = 401, "you must be authenticated"
      render 'v1/blank', :status => @status
    end
  end
  
  def cookie_to_hash(c, delim=",", split="=")
    entries = c.blank? ? nil : c.split(delim)
    h = {}
    return h if entries.blank?
    
    entries.each do |entry|
      key, val = entry.split("=", 2)
      h[key.to_sym] = val
    end
    
    h
  end

  private
  
    def debug_cookies_and_session
      Rails.logger.info "Request: cookies: #{cookies.inspect} --//-- session: #{session.inspect}"
    end
    
    # === These headers are set to allow cross site access and cookies to be sent via ajax
    # - see: http://www.tsheffler.com/blog/?p=428 and
    #         https://developer.mozilla.org/En/Server-Side_Access_Control
    #
    # N.B. "when responding to a credentialed request,  server must specify a domain, and cannot use wild carding."
    # via https://developer.mozilla.org/En/HTTP_access_control#Requests_with_credentials
    # ...but Access-Control-Allow-Origin will be overridden if origin is on of ours: see config/application.rb
    def set_access_control_headers
      headers['Access-Control-Allow-Origin'] = (['web.gt.shelby.tv', 'gt.shelby.tv', 'isoroll.shelby.tv', 'shelby.tv', 'unicorn.shelby.tv', 'localhost.shelby.tv:3000'].include?(request.domain) ? request.domain : '*')
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version, X-CSRF-Token, X-Shelby-User-Agent'
    end
    
end
