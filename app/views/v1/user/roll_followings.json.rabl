collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

# Normally these attributes have to be calculated, but here are injected by the UserController
attributes :creator_nickname, :following_user_count

# Only setting this when roll is retrieved via roll_followings
code :followed_at do |r|
  rf = current_user.roll_following_for r
  rf.id.generation_time.to_f if rf
end

code :subdomain do |r|
  r.subdomain if r.subdomain_active
end