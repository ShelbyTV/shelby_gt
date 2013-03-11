class StatsMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics

  helper :mail

  def weekly_curator_stats(user_to)
    sendgrid_category Settings::Email.weekly_curator_stats["category"]
    sendgrid_ganalytics_options(:utm_source => "#{user_to.id.to_s}", :utm_medium => "#{Time.now.strftime('%Y-%m-%d')}", :utm_campaign => 'weekly_curator_stats')

    @user = user_to

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => user_to.primary_email,
      :subject => Settings::Email.weekly_curator_stats['subject'] % {:curators_name => user_to.name || user_to.nickname}
  end
end
