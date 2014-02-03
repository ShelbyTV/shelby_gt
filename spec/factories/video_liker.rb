Factory.sequence :video_liker_nickname do |n|
  "nickname#{n}"
end

Factory.define :video_liker do |vl|
  vl.nickname { Factory.next :video_liker_nickname }
  vl.has_shelby_avatar false
end