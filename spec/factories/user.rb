# Needed for testing with Devise
Factory.sequence :nickname do |n|
  "nickname#{n}"
end

Factory.define :user do |user|
  user.nickname                 { Factory.next :nickname }
end

