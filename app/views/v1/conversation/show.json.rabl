object @conversation

attributes :id, :public

if user_signed_in?
	child :messages do
		extends 'v1/messages/show'
	end
end