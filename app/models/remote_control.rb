class RemoteControl
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::RemoteControl
  
  key :code, String, :abbr => :a
  
  before_create :build_code
  
  def url
    "#{Settings::ShelbyAPI.web_root}/r/#{self.code}"
  end
  
  private
    def build_code
      self.code = RemoteControl.count.to_s(16)
    end
    
end