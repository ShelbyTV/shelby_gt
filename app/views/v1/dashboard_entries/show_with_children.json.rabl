object @entry

attributes :id, :action, :actor_id, :read

child :frame do
	extends 'v1/frame/show'
	
	child :creator => "creator" do
		extends 'v1/user/show'
	end
	
	child :roll => "roll" do
		extends 'v1/roll/show'
	end
	
	child :video => "video" do
		extends 'v1/video/show'
	end
	
	child :conversation => "conversation" do
		extends 'v1/conversation/show'
	end
	
end