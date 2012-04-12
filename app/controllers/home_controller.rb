class HomeController < ApplicationController  
  
  def index
    
  end
  
  #for blitz.io
  def verification
    render :text => "42"
  end
  
end