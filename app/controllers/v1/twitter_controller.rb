require "api_clients/twitter_client"

class V1::TwitterController < ApplicationController  
  
  before_filter :user_authenticated?
  
  ##
  # Follow the given user on twitter (if the current_user has auth'd with twitter)
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/twitter/follow/USERNAME
  # @param [Required, String] USERNAME (must be part of the url) the twitter username you'd like the current user to follow
  #
  def follow
    return render_error(400, "must provide a twitter user to follow") unless params[:twitter_user_name]
    auth = current_user.first_provider("twitter")
    return render_error(404, "user #{current_user.id} does not have a valid twitter authentication") unless auth and auth.oauth_token and auth.oauth_secret
    
    # Do the follow asynchronously
    ShelbyGT_EM.next_tick do
      c = APIClients::TwitterClient.build_for_token_and_secret(auth.oauth_token, auth.oauth_secret)
      begin
        c.friendships.create! :screen_name => params[:twitter_user_name]
      rescue => e
        Rails.logger.error "Twitter Follow Failed.  Shelby user: #{current_user.id}.  Trying to follow: #{params[:twitter_user_name]}.  Error: #{e}"
      end
    end
    
    @status = 200
    render 'v1/blank'
  end
  
end