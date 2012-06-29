object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url
attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
  r.creator.nickname
end

code :following_user_count do |r|
	r.following_users.count
end

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image
	end
end
