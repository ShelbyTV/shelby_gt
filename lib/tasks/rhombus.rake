namespace :rhombus do

  desc 'Send user data to Rhombus'
  task :total_users => :environment do
    require 'rhombus'
    puts 'executing rhombus rake'
    rhombus = Rhombus.new('shelby', '_rhombus_gt')
    total_users = User.count()
    total_real_users = User.where(:faux.ne => 1).count()
    total_faux_users = total_users - total_real_users
    pp rhombus.post('/set', {:args => ['total_users', total_users]})
    pp rhombus.post('/set', {:args => ['total_real_users', total_real_users]})
    pp rhombus.post('/set', {:args => ['total_faux_users', total_faux_users]})
  end

end
