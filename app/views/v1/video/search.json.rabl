object false

node(:status) { |m| @response[:status] }
node(:query) { |m| @query }
node(:limit) { |m| @response[:limit] }
node(:page) { |m| @response[:page] }
node(:videos) { |m| @response[:videos] }