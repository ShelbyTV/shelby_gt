class MortarMailer < ActionMailer::Base

  def mortar_recommendation_trial(user_to, recs, do_include_reason=false)

    @user = user_to
    @recs = recs
    @do_include_reason = do_include_reason

    mail :from => "Shelby.tv Mortar Trial <dev@shelby.tv>",
      :to => user_to.primary_email,
      :subject => "Your Shelby.tv recommendations, powered by MortarData"
  end
end