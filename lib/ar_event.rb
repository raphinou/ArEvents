
class ArEvent
  attr_accessor :listeners
  def initialize(ev)
    @event = ev
    @listeners = []
  end

  def add_listener(l)
    @listeners << l
  end

  def remove_listener(l)
    @listeners.reject! {|i| i==l}
  end

  def fire(obj)
    @listeners.each do |l|
      l.trigger(@event, obj)
    end
  end
end
