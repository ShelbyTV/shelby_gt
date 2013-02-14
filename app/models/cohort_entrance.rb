# encoding: utf-8
#
# This allows folks to hit a URL like http://api.shelby.tv/cohort_entrance/WHATEVER
# which will allow them to sign up for GT and set their initial cohort
#
# Designed for pre-launch testing of GT
#
class CohortEntrance
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::CohortEntrance
  
  key :code, String, :requried => true, :abbr => :a
  validates_presence_of :code
  
  key :cohorts, Array, :typecast => 'String', :required => true, :abbr => :b
  validates_presence_of :cohorts
  
  key :used_by, Array, :typecase => "ObjectId", :abbr => :c
  
  def url() "http://#{Settings::Global.api_host}/cohort_entrance/#{self.code}"; end
  
  def created_at() self.id.generation_time; end
  
  def used!(user)
    user.cohorts += self.cohorts 
    user.save
    
    self.used_by << user.id
    self.save
  end
end