Factory.sequence :cohort_code do |n|
  "cohort_code_#{n}"
end

Factory.define :cohort_entrance do |c|
  c.code        { Factory.next :cohort_code }  
  c.cohorts     ["cohort1", "cohort2"]
end