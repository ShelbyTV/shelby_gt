Warden::Manager.after_set_user do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => {:authenticated_user_id => user.id},
    :expires => 1.week.from_now,
    :domain => '.shelby.tv'
  }
  Rails.logger.info("after_set_user callback: #{auth.cookies.inspect}}")
end

Warden::Manager.before_logout do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => {:authenticated_user_id => nil},
    :expires => 1.week.from_now,
    :domain => '.shelby.tv'
  }
  Rails.logger.info("after_set_user callback: auth: #{auth.cookies.inspect}")
end