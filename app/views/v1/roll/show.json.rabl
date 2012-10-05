object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :header_image_file_name, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

code :subdomain do |r|
  r.subdomain if r.subdomain_active
end

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
  r.creator.nickname
end

code :following_user_count do |r|
	r.following_users.count
end

# not too slow b/c we're only dealing with a single roll
code :followed_at do |r|
  if current_user and (rf = current_user.roll_following_for(r))
    rf.id.generation_time.to_f
  else
    0
  end
end

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image, :has_shelby_avatar
	end
end
