class OauthController < ApplicationController
  def authorize
    #if current user is logged in
    if current_user
      render :action=>"authorize"
    else
      render 'login_page'
    end
  end

  def grant
    head oauth.grant!(current_user.id)
  end

  def deny
    head oauth.deny!
  end
end
