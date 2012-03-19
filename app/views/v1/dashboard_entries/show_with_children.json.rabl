object @entry

attributes :id, :action, :actor_id, :read

child :frame do
	extends 'v1/frame/show'
	
	child :roll do
		extends 'v1/roll/show'
	end
	
	child :video do
		extends 'v1/video/show'
	end
	
	child :conversation do
		extends 'v1/conversation/show'
	end
	
end