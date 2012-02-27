require 'em_test_helper'

class TestBlackPressureLevel < Test::Unit::TestCase

  def test_udp_set_and_get_blackpressure_level
    setup_timeout(2)

    EM.run do
      EM.open_datagram_socket("127.0.0.1", next_port) do |c|
        # Check default value.
        assert_equal 32768, c.backpressure_level
        # Modify and check value.
        c.backpressure_level = 123456
        assert_equal 123456, c.backpressure_level
        EM.stop
      end
    end
  end

  def test_tcp_set_and_get_blackpressure_level
    setup_timeout(2)

    EM.run do
      EM.start_server("127.0.0.1", port = next_port) do |c|
        # Check default value.
        assert_equal 32768, c.backpressure_level
        c.backpressure_level = 123456
        # Modify and check value.
        assert_equal 123456, c.backpressure_level
        EM.stop
      end

      EM.connect("127.0.0.1", port)
    end
  end

end
