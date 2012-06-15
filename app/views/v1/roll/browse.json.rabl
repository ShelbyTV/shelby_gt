collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count
attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url

if @frames
	node :frames do |r|
		r['frames_subset']
	end
end