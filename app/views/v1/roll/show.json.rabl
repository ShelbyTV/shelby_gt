object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :header_image_file_name, :content_updated_at, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

code :subdomain do |r|
  r.subdomain if r.subdomain_active
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

node(:creator_has_shelby_avatar, :if => lambda { |r| r.creator != nil }) do |r|
  if r.creator.avatar_file_name && (r.creator.avatar_file_name.length > 0)
    true
  else
    false
  end
end

node(:creator_avatar_updated_at, :if => lambda { |r| r.creator != nil }) do |r|
  r.creator.avatar_updated_at
end

node(:discussion_roll_participants, :if =>  lambda { |r| r.roll_type == Roll::TYPES[:user_discussion_roll]}) do |r|
  r.discussion_roll_participants
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

if @insert_discussion_roll_access_token == true
  node(:token) do |r|
    GT::DiscussionRollUtils.encrypt_roll_user_identification(r, @user_identifier)
  end
end