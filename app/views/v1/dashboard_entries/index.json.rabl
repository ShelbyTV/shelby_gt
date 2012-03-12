collection @entries, :root => "dashboard"

if @include_children == true
	extends 'v1/dashboard_entries/show_with_children'
else
	extends 'v1/dashboard_entries/show'
end