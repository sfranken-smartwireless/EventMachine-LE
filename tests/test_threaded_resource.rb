class TestThreadedResource < Test::Unit::TestCase
  def object
    @object ||= {}
  end

  def resource
    @resource = EM::ThreadedResource.new do
      object
    end
  end

  def teardown
    resource.shutdown
  end

  def test_dispatch_completion
    EM.run do
      completion = resource.dispatch do |o|
        o[:foo] = :bar
        :foo
      end
      completion.callback do |result|
        assert_equal :foo, result
        EM.stop
      end
    end
    assert_equal :bar, object[:foo]
  end

  def test_dispatch_failure
    completion = resource.dispatch do |o|
      raise 'boom'
    end
    completion.errback do |error|
      assert_kind_of RuntimeError, error
      assert_equal 'boom', error.message
    end
  end

  def test_dispatch_threading
    main = Thread.current
    resource.dispatch do |o|
      o[:dispatch_thread] = Thread.current
    end
    assert_not_equal Thread.current, object[:dispatch_thread]
  end

  def test_shutdown
    # This test should get improved sometime. The method returning thread is
    # NOT an api that will be maintained.
    assert !resource.shutdown.alive?
  end
end