collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network
attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url

node(:creator_nickname, :if => lambda { |r| r.creator != nil }) do |r|
  r.creator.nickname
end

if @frames
	node :frames do |r|
		r['shallow_frames']
	end
end