require 'rack/oauth2/server'

class OauthController < ApplicationController
  before_filter :set_current_user
  def authorize
    #if current user is logged in
    if current_user
      render :action=>"authorize"
    else
      session[:return_url] = request.url
      render 'gate'
    end
  end

  def index
    render 'index'
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
    @user.applications << client.id
    @user.save
    render "index"

  end

  def clientpage
    appid = params[:appid]
    if @user.applications.include?appid
      render :text=>"nothing here"
    end
    @client = Rack::OAuth2::Server::Client.find(appid)
  end


  protected
    def set_current_user
      if current_user
        puts "OKKKKKKKKKKKKKKKKKKKKKK"
        @user = current_user
      else
        session[:return_url] = request.url
        render 'gate'
      end
    end

end
