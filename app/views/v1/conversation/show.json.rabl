object @conversation

attributes :id, :public

child :messages => 'messages' do
	extends 'v1/messages/show'
end