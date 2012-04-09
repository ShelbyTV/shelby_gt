object @frame

if @include_frame_children == true

	attributes :id, :score, :upvoters, :frame_ancestors, :frame_children

	child :roll => "roll" do
		extends 'v1/roll/show'
	end

	child :creator => "creator" do
		attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux
	end

	child :video => "video" do
		extends 'v1/video/show'
	end

	child :conversation => "conversation" do
		extends 'v1/conversation/show'
	end
else
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
end