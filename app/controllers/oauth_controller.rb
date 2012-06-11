require 'rack/oauth2/server'

class OauthController < ApplicationController
  def authorize
    #if current user is logged in
    if current_user
      render :action=>"authorize"
    else
      session[:return_url] = request.url
      render 'login_page'
    end
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
    client_params = params[:post]
    client = Rack::OAuth2::Server.register(:display_name=>client_params[:display_name],
                                           :link=>client_params[:website_link],
                                           :image_url=>client_params[:image_url],
                                           :redirect_uri=>client_params[:redirect_url])
    @id = client.id
    @secret = client.secret
    puts @id
    puts @secret
    render "create"

  end

end
