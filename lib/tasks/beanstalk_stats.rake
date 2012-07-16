namespace :beanstalk do

  desc 'Send all beanstalk tube stats to Graphite via UDP'
  task :update_stats => :environment do
    require 'stats_manager'
    
    @bean = Beanstalk::Connection.new(Settings::Beanstalk.url)
    
    begin
      @bean.list_tubes.each do |t| 
        begin
          # get all the stats from each tube
          stats = @bean.stats_tube(t)
          
          # pass each stat to graphite
          stats.each do |k,v|
            unless k == "name"
              statd_name = "#{t}.#{k}"
              StatsManager::StatsD.count(statd_name, v)
            end
          end
        rescue => e
          puts "[ERROR] Trying to get stats for #{t} tube: #{e}"
        end
      end
    rescue => e
      puts "[ERROR] Trying to get list of tubes: #{e} "
    end
  end
  
end