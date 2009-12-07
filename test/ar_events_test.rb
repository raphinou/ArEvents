#require 'test_helper'
#The approach in these tests is borrowed from callbacks_observers_test
require File.dirname(__FILE__)+'/../../../../test/test_helper.rb'

class ArEventComment < ActiveRecord::Base
  attr_accessor :triggered
  after_save :comment_after_save

  def comment_after_save
    record_triggered(self.class)
  end

  def record_triggered(klass)
    triggered << klass if triggered
  end
end

ArEventComment.send(:include, ArEvents)

class ArEventSubComment < ArEventComment
end




class ArEventCommentListener
  def self.trigger(evt, obj)
    obj.record_triggered self
  end
end

class SecondArEventCommentListener
  def self.trigger(evt, obj)
    obj.record_triggered self
  end
end

class ArEventsTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Schema.define do
      create_table :ar_event_comments, :force => true do |t|
        t.column :title, :string
        t.column :body, :string
        t.column :type, :string
      end
    end

  end
  def teardown
    ActiveRecord::Schema.define do
      drop_table :ar_event_comments
    end
  end
  def init_env
    triggered = []
    @comment = ArEventComment.new
    @comment.triggered = triggered
  end
  # Replace this with your real tests.
  test "check event_listener was triggered" do


    # test with listener added and active
    ArEventComment.add_ar_event_listener(:before_validation, ArEventCommentListener)
    init_env
    @comment.valid?
    assert_equal [ArEventCommentListener], @comment.triggered, "the listener was not called correctly"

    #test with listener added but ignored
    init_env
    @comment.ignore_ar_event(:before_validation)
    @comment.valid?
    assert_equal [], @comment.triggered, "the listener wasnot ignored despite being added in ignored_ar_events "

    #test with listener added then removed
    init_env
    ArEventComment.remove_ar_event_listener(:before_validation, ArEventCommentListener)
    init_env
    @comment.valid?

    assert_equal [], @comment.triggered, "the listener was not removed correctly"

    #listener in addition to callback defined in model
    ArEventComment.add_ar_event_listener(:after_save, ArEventCommentListener)
    init_env
    @comment.save
    assert_equal [ArEventComment,ArEventCommentListener], @comment.triggered, "listener in addition to callback didn't work as expected"
    #multiple listeners for multiple events
    ArEventComment.reset_ar_event_listeners
    ArEventComment.add_ar_event_listener(:before_validation, ArEventCommentListener)
    ArEventComment.add_ar_event_listener(:after_save, SecondArEventCommentListener)
    init_env
    @comment.save
    assert_equal [ArEventCommentListener,ArEventComment,SecondArEventCommentListener], @comment.triggered, "multiple listeners to multiple events in addition to callback didn't work as expected"

    #Resetting listeners
    ArEventComment.reset_ar_event_listeners
    init_env
    @comment.save
    assert_equal [ArEventComment], @comment.triggered, "resetting listeners didn't work"


   #Problem: the clas instance variable ar_events is not available in subclasses, and this causes trouble
   #tried to solve it with self.inherited but to no avail
    triggered = []
    @comment = ArEventSubComment.new
    @comment.triggered = triggered
    ArEventComment.add_ar_event_listener(:before_validation, ArEventCommentListener)
    @comment.valid?
    assert_equal [ArEventCommentListener], @comment.triggered

   #Now we include the module in the subclass also!

    ArEventComment.reset_ar_event_listeners

    # Add a listener to the parent class and none to the subclass
    ArEventComment.add_ar_event_listener(:before_validation, ArEventCommentListener)
    ArEventSubComment.send(:include, ArEvents)
    triggered = []
    @comment = ArEventSubComment.new
    @comment.triggered = triggered
    @comment.valid?
    assert_equal [ ArEventCommentListener ], @comment.triggered, "the listener of the parent class was not called when it should have been"


    # add a listener to the subclass
    # the listener of the parent class should not be called
    triggered = []
    @comment = ArEventSubComment.new
    @comment.triggered = triggered
    ArEventSubComment.add_ar_event_listener(:before_validation, SecondArEventCommentListener)
    @comment.valid?
    assert_equal [ArEventCommentListener,SecondArEventCommentListener], @comment.triggered, "the listener of the subclass was not called as expected"
  end
end
