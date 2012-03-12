object @roll

attributes :id

child :frames do
	attributes :id, :score, :video_id, :conversation_id, :creator_id, :upvoters, :frame_ancestors, :frame_children
end