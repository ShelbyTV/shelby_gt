require 'rack/oauth2/server'

class OauthController < ApplicationController
  before_filter :set_current_user
  def authorize
    StatsManager::StatsD.increment(Settings::StatsConstants.oauth["authorize"])
    #if current user is logged in
    if current_user.clients.include? get_client_id
      redirect_to "/oauth/grant?authorization=#{oauth.authorization}"
    else
      render :action=>"authorize"
    end
  end

  def index
    @user = current_user
    render 'index'
  end


  def grant
    client_id = get_client_id
    current_user.clients << client_id.to_s unless current_user.clients.include? client_id
    current_user.save
    StatsManager::StatsD.increment(Settings::StatsConstants.oauth["grant"])
    head oauth.grant!(current_user.id)
  end

  def deny
    StatsManager::StatsD.increment(Settings::StatsConstants.oauth["deny"])
    head oauth.deny!
  end

  def delete
    client_id = params[:client_id]
    current_user.revoke(Rack::OAuth2::Server::Client.find(client_id))
    current_user.clients.delete(client_id)
    current_user.save
    StatsManager::StatsD.increment(Settings::StatsConstants.oauth["delete"])
    redirect_to "/oauth/grantpage"
  end

  def register
  end

  def create
    @user = current_user
    client = Rack::OAuth2::Server.register(:display_name=>params["app_name"],
                                           :link=>params["website_link"],
                                           :image_url=>params["image_url"],
                                           :redirect_uri=>params["callback_url"])
    @client = client
    current_user.applications << client.id.to_s
    current_user.save
    StatsManager::StatsD.increment(Settings::StatsConstants.oauth["create"])
    render "index"
  end

  def grantpage
    @user = current_user
    @client_list = []
    @user.clients.each do |app_id|
      client = Rack::OAuth2::Server::Client.find(app_id)
      @client_list << client unless client.nil?
    end
  end 

  def clientpage
    @user = current_user
    appid = params[:appid]
    unless current_user.applications.include? appid
      render :text=>"nothing here"
    end
    @client = Rack::OAuth2::Server::Client.find(appid)
  end



  protected
    def set_current_user
      unless current_user
        session[:return_url] = request.url
        render 'gate'
      end
    end

  private
    def get_client_id
      Rack::OAuth2::Server.get_auth_request(oauth.authorization).client_id.to_s if oauth.authorization
    end

end
