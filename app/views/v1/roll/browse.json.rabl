collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :header_image_file_name, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

code :subdomain do |r|
  r.subdomain if r.subdomain_active
end

code :following_user_count do |r|
	r.following_users.count
end

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
  if r.creator.user_type == 1 && r.creator.authentications && !r.creator.authentications.empty?
    r.creator.authentications[0].nickname
  else
    r.creator.nickname
  end
end

node(:creator_name, :if => lambda { |r| r.creator != nil }) do |r|
  if r.creator.user_type == 1 && r.creator.authentications && !r.creator.authentications.empty?
    r.creator.authentications[0].name
  else
    r.creator.name
  end
end