# ArEvents
module ArEvents

  def self.extended(base)
    base.class_eval do
      #define an attribute accessor on the class
      class << self
        attr_accessor :ar_events
        attr_accessor :ignored_ar_events
      end
      #initialize the value of the attribute accessed by the ar_events attribute accessor
      @ar_events = {}
      #For each callback we define an ar_event
      ActiveRecord::Callbacks::CALLBACKS.each do |cb|
        # add our method to the chain of callbacks. 
        # Here's what generated for the after_save callback
        # after_save, :ar_after_save
        self.send cb, "ar_#{cb}_#{self.to_s}".to_sym
        # Initialize ar_event for that callback
        @ar_events[cb] = ArEvent.new(cb)
        @ignored_ar_events = [] 
        # finally define the method that was added to the callback chain.
        # this method simply fires the corresponding event, which will trigger all listeners
        defining_class = self.to_s
        define_method("ar_#{cb}_#{self.to_s}".to_sym) do
          # we tested if the object generating the event is of our own class or of a subclass
          # only fire events for instances of our own class, not of subclasses
          # this is needed because callback chains are inherited. So a subclass will call all ar_event methods of all parents, 
          # which will result in multiple firing of the listeners of an event because all ar_event methods called, even those from parents, 
          # will use the listeners defined at the subclass level
          # this code is not used anymore as we now call all listeners of the defining_class below
          #if self.class.to_s != defining_class
          #  #skipping these as it was not fired by an instance of our own class
          #  return
          #end
          #puts "firing event #{cb} on class #{self.class} in #{this_method_name} "
          #puts "listeners are (class #{self.class} ): #{self.class.ar_events[cb].listeners.inspect}"
          #puts "firing event #{cb} on class #{defining_class} in #{this_method_name} "
          #puts "listeners are (class #{defining_class} ): #{Object.const_get(defining_class).ar_events[cb].listeners.inspect}"
          this_class = defining_class.constantize
          this_class.ar_events[cb].fire(self) unless this_class.ignored_ar_events.include?(cb)
        end
      end
    end
  end


    def add_ar_event_listener(evt, listener)
      raise "Callback requested (#{evt}) is unknown" unless ActiveRecord::Callbacks::CALLBACKS.include?(evt.to_s)
      self.ar_events[evt.to_s].add_listener listener
    end
    def remove_ar_event_listener(evt, listener)
      raise "Callback requested (#{evt}) is unknown" unless ActiveRecord::Callbacks::CALLBACKS.include?(evt.to_s)
      self.ar_events[evt.to_s].remove_listener listener
    end
    def reset_ar_event_listeners
      self.ar_events.each do |k,v|
        self.ar_events[k] = ArEvent.new(k)             
      end
    end
    # Keep ignored_ar_events in an class instance variable.
    def ignored_ar_events=(a)
      self.ignored_ar_events = a
    end
    def initialize_ignored_ar_events
      self.ignored_ar_events = []
    end
    def ignore_ar_events(*evt, &block)
      if block
        original_ignored_events = self.ignored_ar_events
        self.ignored_ar_events +=  evt.collect{|e| e.to_s}
        yield
        self.ignored_ar_events = original_ignored_events
      else
        self.ignored_ar_events +=  evt.collect{|e| e.to_s}
      end
    end
    def restore_ar_event(*evt)
      self.ignored_ar_events -= evt.collect{|e| e.to_s }
    end
# This causes the problem "can't dup NilClass" when instanciating subclass
#    def inherited(subclass)
#      subclass.instance_variable_set("@ar_events", instance_variable_get("@ar_events"))
#    end
end

