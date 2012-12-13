object @remote_control

attributes :id, :code

node(:command) { |m| @command }

if @data
	node(:data) { |m| @data }
end