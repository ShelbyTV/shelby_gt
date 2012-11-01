Factory.sequence :provider_id do |n|
  "id#{n}"
end

Factory.define :video do |v|
  v.provider_name     "youtube"
  v.provider_id       { Factory.next :provider_id }
  v.title             { Factory.next :title }
end