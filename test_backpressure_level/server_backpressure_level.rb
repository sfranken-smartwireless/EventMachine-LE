#!/usr/bin/ruby

$0 = "server_blackpressure_level.rb"

lib_dir = File.expand_path(File.join(File.dirname(__FILE__), "../", "lib"))
$LOAD_PATH.insert(0, lib_dir)

require "eventmachine-le"
begin
  require "iobuffer"
rescue LoadError
  $stderr.puts "ERROR: iobuffer gem is required:\n  gem install iobuffer"
  exit 1
end
require "socket"


class Message
  attr_accessor :connection, :data, :source_ip, :source_port
  
  def initialize(data)
    @data = data
  end
end



class TestLeakServer < EM::Connection

  attr_reader :source_ip, :source_port

  def initialize
    super
    @buffer = IO::Buffer.new
    @state = :init
    @num_request = 0
    @num_response = 0
  end

  def post_init
    @source_port, @source_ip = ::Socket.unpack_sockaddr_in(get_peername)
    puts "post_init: self.object_id = #{self.object_id}"
  end

  def unbind cause=nil
    puts "unbind(#{cause.inspect})"
    exit 1
  end
    
  def receive_data(data)
    @buffer << data

    while case @state
      when :init
        @state = :message
      when :message
        parse_message
      when :finished
        process_request(@msg)
        @state = :init
      when :invalid
        $stderr.puts "FATAL: state invalid"
        raise "invalid state!!!"
      else
        raise RuntimeError, "invalid state: #{@state}"
      end
    end
  end

  def parse_message
    return false if @buffer.size < 1

    @msg = Message.new(@buffer.read(1))
    @num_request += 1
    @state = :finished

    return true
  end

  def process_request(msg)
    puts "requests = #{@num_request}  -  responses = #{@num_response}  =>  diff = #{@num_request-@num_response}"

    msg.source_ip = @source_ip
    msg.source_port = @source_port
    
    if msg.data == "A"
      send_data "a"
      @num_response += 1
      
    elsif msg.data == "B"
      EM.next_tick do
        send_data "b"
        @num_response += 1
      end

    elsif msg.data == "C"
      msg.connection = self
      operation = proc { msg }
      callback = proc do |result|
        result.connection.send_data "c"
        @num_response += 1
      end
      EM.defer( operation, callback )

    else
      raise "msg.data is not \"A\" or \"B\" or \"C\" !!!"
    end

    return true
  end

end


EM.threadpool_size = 10
EM.run do

  EM.start_server("127.0.0.1", 6666, TestLeakServer) do |c|
    #c.backpressure_level = 1000
  end
  puts "INFO: TCP server listening on 0.0.0.0:6666"

  EM.add_periodic_timer(3) do
    $stderr.puts
    $stderr.puts "[[[ #{Time.now} ]]]"
    GC.start
    $stderr.puts "GC.start executed"
    $stderr.puts "ObjectSpace.each_object:"
    $stderr.puts "TOTAL objets:              #{ObjectSpace.each_object() {} }"
    $stderr.puts "TOTAL EM::Connection:      #{ObjectSpace.each_object(EM::Connection) {} }"
    $stderr.puts "TOTAL TestLeakServer:      #{ObjectSpace.each_object(TestLeakServer) {} }"
    num_conn = 0
    ObjectSpace.each_object(TestLeakServer) do |conn|
      if conn.source_port and (num_conn+=1) <= 20
        $stderr.puts "- connection: source port = #{conn.source_port} | error? = #{conn.error?} | object_id = #{conn.object_id}"
      end
    end
    $stderr.puts "TOTAL Message:             #{ObjectSpace.each_object(Message) {} }"
    num_msg = 0
    ObjectSpace.each_object(Message) do |msg|
      $stderr.puts "- message source port: #{msg.source_port}"
      if (num_msg+=1) > 20
        $stderr.puts "- [more...]"
        break
      end
    end
  end
  
end

