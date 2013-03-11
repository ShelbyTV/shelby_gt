namespace :stats_emails do

  desc 'Send Weekly Curator Stats Email'
  task :send_weekly_curator_stats_emails => :environment do

    active_curator_ids = ['adventurous','brendancoffey','bsoist','chris','emily','enelson1','evilmusic','food52','frash','hangingwithcornellians','henry','joaquin','johnvehr','jtest13','kehrseite','lfleisch','matyus','migupatricio','mobilona','nerdfitness','nm33','quilting','sheynk','smallscreen','spookybeans','tajcor','techstars','theresa','tomreynolds']
    active_curators = User.where(:nickname => { :$in => active_curator_ids })

    active_curators.find_each do |u|

      if u.primary_email && u.primary_email != "" && u.preferences.email_updates
        StatsMailer.weekly_curator_stats(u).deliver
      end

    end

  end

end