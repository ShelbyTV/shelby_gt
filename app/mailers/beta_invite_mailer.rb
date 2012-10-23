class BetaInviteMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack
  
  helper :mail, :application

  def initial_invite(invite)
    sendgrid_category Settings::Email.beta_invite["initial"]["category"]
    
    @invite = invite
    @inviter = invite.sender
    @inviters_name = invite.sender.name || invite.sender.nickname
    
    from = "\"#{@inviters_name}\" <#{invite.sender.primary_email}>" || Settings::Email.beta_invite["initial"]['from']
    subj = invite.email_subject || Settings::Email.beta_invite['initial']['subject'] % {:inviters_name => @inviters_name}
    
    mail :from => from, :to => invite.to_email_address, :subject => subj
  end
end
