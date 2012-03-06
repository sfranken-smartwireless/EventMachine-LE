require 'em_test_helper'

class TestCloexec < Test::Unit::TestCase

  class MyTcpServer < EM::Connection
    def post_init
      # Without CLOEXEC patch, this "sleep" process would inherit the EM server socket
      # so the EM client would not be disconnected after killing the EM server with
      # KILL signal.
      EM.system("/bin/sleep 3")
      # Kill ourself with KILL signal after a while.
      EM.add_timer(0.5) { Process.kill 9, $$ }
    end
  end


  def test_execed_process_does_not_inherit_socket
    setup_timeout(2)  # Should never occur.
    port = next_port

    assert_nothing_raised do
      # Fork a EM server into a new process. Otherwise we would
      # kill all the Ruby process.
      EM.fork_reactor do
        EM.start_server("127.0.0.1", port, MyTcpServer)
      end

      sleep 0.2
      EM.run do
        EM.connect("127.0.0.1", port) do |c|
          def c.connection_completed
            EM.add_timer(1) do
              raise "client was not disconnected after killing the EM server with KILL signal"
            end
          end

          def c.unbind cause=nil
            EM.stop
          end
        end
      end  # EM.run do
    end  # assert_nothing_raised do
  end

end
