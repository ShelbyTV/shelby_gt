Warden::Manager.after_set_user do |user, auth, opts|
end

Warden::Manager.before_logout do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => "authenticated_user_id=nil,csrf_token=nil",
    :expires => 1.week.from_now,
    :domain => '.shelby.tv'
  }
end