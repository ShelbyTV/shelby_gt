object @remote_control

attributes :code

node(:command) { |m| @command }

if @data
	node(:data) { |m| @data }
end