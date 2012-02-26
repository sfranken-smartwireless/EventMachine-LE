require 'em_test_helper'

class TestNoCppExceptions < Test::Unit::TestCase

  def test_set_effective_user_with_non_existing_user

    assert_raise ArgumentError do
      EM.run do
        EM.set_effective_user "non_existing_user"
        EM.stop
      end
    end

  end

end
