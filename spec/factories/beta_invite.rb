Factory.define :beta_invite do |i|
  i.to_email_address { Factory.next :primary_email }
end