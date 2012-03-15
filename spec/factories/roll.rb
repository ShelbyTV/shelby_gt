# Needed for integration testing
Factory.sequence :title do |r|
  "title#{r}"
end

Factory.define :roll do |roll|
  roll.title  { Factory.next :title }
end

