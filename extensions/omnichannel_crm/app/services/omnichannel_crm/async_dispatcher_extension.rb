module OmnichannelCrm
  module AsyncDispatcherExtension
    def listeners
      super + [ChatwootEventListener.instance]
    end
  end
end
