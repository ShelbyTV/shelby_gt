collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count
attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url

code :following_user_count do |r|
	r.following_users.count
end

code :first_frame_thumbnail_url do |r|
	r.first_frame_thumbnail_url if r.first_frame_thumbnail_url
end