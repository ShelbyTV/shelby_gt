class V1::BetaInviteController < ApplicationController  
  
  before_filter :user_authenticated?
  
  def create
    return render_error(409, "No invites left", {:user => {:beta_invites_available => ["none available"]}}) unless current_user.beta_invites_available > 0
    
    @invite = BetaInvite.new(:to_email_address => params[:to], :email_body => params[:body], :email_subject => params[:subject])
    @invite.sender = current_user
    if @invite.save
      current_user.update_attribute(:beta_invites_available, current_user.beta_invites_available - 1)
      @status = 200
      ShelbyGT_EM.next_tick { 
        BetaInviteMailer.initial_invite(@invite).deliver
        # XXX send event to KM
      }
    else
      render_errors_of_model(@invite)
    end
  end
  
end