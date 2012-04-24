class GtInterestMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def interest_autoresponse(email_to)
    sendgrid_category Settings::Email.gt_interest_autoresponse["category"]
    mail :from => Settings::Email.gt_interest_autoresponse['from'], :to => email_to, :subject => Settings::Email.gt_interest_autoresponse['subject']
  end
end
