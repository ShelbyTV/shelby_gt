Factory.sequence :rec_score do |n|
  n
end

Factory.define :recommendation do |r|
  r.score   { Factory.next :rec_score }
end