namespace :rhombus do

  desc 'Send user data to Rhombus'
  task :total_users => :environment do
    require 'rhombus'
    puts 'executing rhombus rake'
    rhombus = Rhombus.new('shelby', '_rhombus_gt')
    total_users = User.count()
    total_real_users = User.where(:faux.ne => 1).count()
    total_faux_users = total_users - total_real_users
    total_videos = Video.count()
    total_frames = Frame.count()
    total_rolls = Roll.count()
    total_conversations = Conversation.count()
    pp rhombus.post('/set', {:args => ['total_users', total_users]})
    pp rhombus.post('/set', {:args => ['total_real_users', total_real_users]})
    pp rhombus.post('/set', {:args => ['total_faux_users', total_faux_users]})
    pp rhombus.post('/set', {:args => ['total_videos', total_videos]})
    pp rhombus.post('/set', {:args => ['total_frames', total_frames]})
    pp rhombus.post('/set', {:args => ['total_rolls', total_rolls]})
    pp rhombus.post('/set', {:args => ['total_conversations', total_conversations]})
  end

end
