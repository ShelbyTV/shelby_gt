class V1::BetaInviteController < ApplicationController  
  
  before_filter :user_authenticated?
  
  def create
    @invite = BetaInvite.new(:to_email_address => params[:to], :email_body => params[:body], :email_subject => params[:subject])
    @invite.sender = current_user
    if @invite.save
      @status = 200
      ShelbyGT_EM.next_tick { BetaInviteMailer.initial_invite(@invite).deliver }
    else
      render_errors_of_model(@invite)
    end
  end
  
end