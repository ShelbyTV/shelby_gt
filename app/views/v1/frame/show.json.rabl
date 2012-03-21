object @frame

if @include_frame_children == true

	attributes :id, :score, :upvoters, :frame_ancestors, :frame_children

	child :roll do
		extends 'v1/roll/show'
	end

	child :creator => :creator do
		extends 'v1/user/show'
	end

	child :video do
		extends 'v1/video/show'
	end

	child :conversation do
		extends 'v1/conversation/show'
	end
else
	attributes :id, :score, :upvoters, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
end