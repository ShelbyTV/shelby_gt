class Rhombus
  include HTTParty
  base_uri 'http://localhost:3010'

  def initialize(u, p)
    @auth = {:username => u, :password => p}
  end

  def post(path, data)
    options = {:body => data, :basic_auth => @auth}
    self.class.post(path, options)
  end

end
