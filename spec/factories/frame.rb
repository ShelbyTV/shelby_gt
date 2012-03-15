Factory.sequence :score do |n|
  n
end

Factory.define :frame do |f|
  f.score   { Factory.next :score }
end