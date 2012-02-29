# We need to override some of the stuff MongoMapper does by default.

namespace :db do

  namespace :indexes do
    
    desc 'Ensure we have created the indexes we need'
    task :ensure => :environment do
      require "mongo_mapper_helper"
      MongoMapper::Helper.ensure_all_indexes
    end
    
  end
  
end
