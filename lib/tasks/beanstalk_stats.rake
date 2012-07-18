namespace :beanstalk do

  desc 'Send all beanstalk tube stats to Graphite via UDP'
  task :update_stats => :environment do
    
    @bean = Beanstalk::Connection.new(Settings::Beanstalk.url)
    @statsd = Statsd.new(Settings::StatsD.statsd_server, Settings::StatsD.statsd_port)
    
    begin
      @bean.list_tubes.each do |t| 
        begin
          # get all the stats from each tube
          stats = @bean.stats_tube(t)
          
          # pass each stat to graphite
          stats.each do |k,v|
            unless k == "name"
              statd_name = "beanstalk.#{t}.#{k}"
              @statsd.count(statd_name, v)
            end
          end
        rescue
          @statsd.count("beanstalk.error.#{t}", v)
        end
      end
    rescue
      @statsd.count("beanstalk.error.getting_tubes", v)
    end
  end
  
end