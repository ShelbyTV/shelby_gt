object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :header_image_file_name, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

code :subdomain do |r|
  r.subdomain if r.subdomain_active
end

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
  if r.creator.user_type == User::USER_TYPE[:faux] && r.creator.authentications && !r.creator.authentications.empty?
    r.creator.authentications[0].nickname
  else
    r.creator.nickname
  end
end

node(:creator_name, :if => lambda { |r| r.creator != nil }) do |r|
  if r.creator.user_type == User::USER_TYPE[:faux] && r.creator.authentications && !r.creator.authentications.empty?
    r.creator.authentications[0].name
  else
    r.creator.name
  end
end

# not too slow b/c we're only dealing with a single roll
code :followed_at do |r|
  rf = current_user.roll_following_for r
  rf ? rf.id.generation_time.to_f : 0
end