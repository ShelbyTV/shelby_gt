# We need to override some of the stuff MongoMapper does by default.

namespace :db do
  namespace :test do
    
    # Since we don't use 1 DB with many collections (as MM default expects), go through all the DBs and all the test collections and drop them
    desc 'Iterate through all the DBs we use and drop all test collections'
    override_task :prepare => :environment do
      puts "TODO: prepare test DBs!"
      #MongoMapper.connect('test')
      #MongoMapper.database.collections.select {|c| c.name !~ /system/ }.each(&:drop)
      #MongoMapper.connect(Rails.env)
    end
    
  end
end

task 'spec' => 'db:test:prepare'