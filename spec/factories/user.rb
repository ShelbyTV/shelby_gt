# Needed for testing with Devise
Factory.sequence :nickname do |n|
  "nickname#{n}"
end

Factory.sequence :uid do |n|
  "12#{n}"
end

Factory.sequence :primary_email do |n|
  "email#{n}@gmail.com"
end

Factory.define :authentication do |a|
  a.name          "name"
  a.nickname      "nickname"
  a.provider      "twitter"
  a.oauth_token   "token"
  a.oauth_secret  "secret"
  a.uid         { Factory.next :uid }
end

Factory.define :user do |user|
  user.nickname                 { Factory.next :nickname }
  user.downcase_nickname        { self.nickname }
  user.authentications          { [FactoryGirl.create(:authentication)] }
  user.primary_email            { Factory.next :primary_email }
  user.gt_enabled true
  user.preferences  Preferences.new
end

