Warden::Manager.after_set_user do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => "authenticated_user_id=#{user.id.to_s}",
    :expires => 1.week.from_now,
    :domain => '.shelby.tv'
  }
end

Warden::Manager.before_logout do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => "authenticated_user_id=nil",
    :expires => 1.week.from_now,
    :domain => '.shelby.tv'
  }
end