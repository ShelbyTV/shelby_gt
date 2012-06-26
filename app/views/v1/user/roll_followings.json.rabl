extend NewRelic::Agent::MethodTracer

collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count
attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
	self.class.trace_execution_scoped(['UserController/roll_followings/creator_nickname']) do 
	  r.creator.nickname
	end
end

code :following_user_count do |r|
	self.class.trace_execution_scoped(['UserController/roll_followings/following_user_count']) do 
		r.following_users.count
	end
end

code :first_frame_thumbnail_url do |r|
	r.first_frame_thumbnail_url if r.first_frame_thumbnail_url
end