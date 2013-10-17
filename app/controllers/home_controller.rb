class HomeController < ApplicationController

  def index

  end

  #for blitz.io
  def blitz
    render :text => "42"
  end

end
