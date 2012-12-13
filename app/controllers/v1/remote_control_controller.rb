class V1::RemoteControlController < ApplicationController  

  def show
    
  end
  
  def update
    
  end
  
  def create
    if @remote_control = RemoteControl.create()
      @status = 200
    else
      render_error(404, "could not create the remote control code :/")
    end
  end
  
  private
    def pusher_client
      unless @pusher_client
        @pusher_client |= Pusher::Client.new({
          app_id: Settings::Pusher.id,
          key: Settings::Pusher.key,
          secret: Settings::Pusher.secret
        })
      end
      @pusher_client
    end
  
end