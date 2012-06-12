require 'rack/oauth2/server'

class OauthController < ApplicationController
  def authorize
    #if current user is logged in
    if true
      render :action=>"authorize"
    else
      session[:return_url] = request.url
      render 'gate'
    end
  end

  def gate
  end

  def grant
    head oauth.grant!(current_user.id)
  end

  def deny
    head oauth.deny!
  end

  def register
  end

  def create
    client = Rack::OAuth2::Server.register(:display_name=>params["app_name"],
                                           :link=>params["website_link"],
                                           :image_url=>params["image_url"],
                                           :redirect_uri=>params["callback_url"])
    @client = client
    render "clientpage"

  end

end
