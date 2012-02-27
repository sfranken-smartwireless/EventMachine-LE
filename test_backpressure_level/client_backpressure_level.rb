#!/usr/bin/ruby

$0 = "client_blackpressure_level.rb"

lib_dir = File.expand_path(File.join(File.dirname(__FILE__), "../", "lib"))
$LOAD_PATH.insert(0, lib_dir)

require "eventmachine-le"
begin
  require "iobuffer"
rescue LoadError
  $stderr.puts "ERROR: iobuffer gem is required:\n  gem install iobuffer"
  exit 1
end


DATA        = ARGV[0]
TIMES       = (ARGV[1].to_i > 0) ? ARGV[1].to_i : 1
CONCURRENCY = ARGV[2] ? ARGV[2].to_i : 1



def show_usage
  puts "
USAGE:  ./em_client_test_leak.rb DATA TIMES CONCURRENCY

 DATA         must be \"A\" or \"B\" or \"C\"
 TIMES        number of messages to send (default 1)
 CONCURRENCY  messages to send together upon receipt of a response (default 1)

"
end

if DATA != "A" and DATA != "B" and DATA != "C"
  $stderr.puts "ERROR: DATA must be \"A\" or \"B\" or \"C\""
  show_usage
  exit 1
end


def calculate_num_requests(sent)
  if (TIMES - sent) < CONCURRENCY
    return TIMES - sent
  else
    return CONCURRENCY
  end
end




class TestLeakClient < EventMachine::Connection

  def initialize
    super
    @buffer = IO::Buffer.new
    @state = :init

    @num_request = 0
    @num_response = 0
  end

  def send_requests
    calculate_num_requests(@num_request).times do
      @num_request += 1
      send_data DATA
    end
  end

  def post_init
    puts "DEBUG: connected"
    send_requests
  end

  def unbind
    puts "\n\nWARN: *** disconnected ***"
  end

  def receive_data(data)
    @buffer << data

    while case @state
      when :init
        @state = :response
        true
      when :response
        parse_response
      when :invalid
        $stderr.puts "FATAL: state invalid"
        raise "invalid state!!!"
      else
        raise RuntimeError, "invalid state: #{@state}"
      end
    end
  end
  


  def parse_response
    return false if @buffer.size < 1

    @response = @buffer.read 1
    @num_response += 1

    puts "requests = #{@num_request}  -  responses = #{@num_response}  =>  diff = #{@num_request-@num_response}"

    if @num_response == TIMES
      puts "\n\nINFO: all the #{TIMES} responses received."
      close_connection_after_writing
      sleep 0.2
      exit 0
    end

    @state = :init
    
    # Send more requests.
    send_requests
    true
  end

end


EM.run do
  puts "INFO: connecting to 127.0.0.1:6666..."
  EventMachine::connect("127.0.0.1", 6666, TestLeakClient) do |c|
    #c.backpressure_level = 2000
  end
end

