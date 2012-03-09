object @frame

attributes :id, :score, :upvoters, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id

child @roll do
	extends "roll/show"
end

child @video do
	extends "video/show"
end

child @rerolls do
		extends "roll/show"
end

child @conversation do
		extends "conversation/show"
end