class MetalController < ActionController::Metal
  def renderMetalResponse(status, json)
    callback, variable = params[:callback], params[:variable]  
    if callback && variable
      self.content_type = "application/javascript" 
      self.response_body = "var #{variable} = #{json};\n#{callback}(#{variable});"  
    elsif variable
      self.content_type = "application/javascript" 
      self.response_body = "var #{variable} = #{json};"  
    elsif callback
      self.content_type = "application/javascript" 
      self.response_body = "#{callback}(#{json});"
    else
      self.content_type = "application/json" 
      self.response_body = "#{json}"
    end
    self.status = status
  end
end
