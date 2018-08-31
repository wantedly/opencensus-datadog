require 'logger'

require 'opencensus/trace/exporters/datadog/transport'
require 'opencensus/trace/exporters/datadog/worker'
require 'opencensus/trace/exporters/datadog/converter'
require 'opencensus/trace/exporters/datadog/buffer'

module OpenCensus
  module Trace
    module Exporters
      class Datadog
        DEFAULT_SERVICE = 'opencensus-app'.freeze

        def self.log
          unless defined? @logger
            @logger = Logger.new(STDOUT)
            @logger.level = Logger::WARN
          end
          @logger
        end

        def initialize(options = {})
          # create HTTP client for sending spans do Datadog Agent
          agent_hostname = options.fetch(:agent_hostname, nil)
          port = options.fetch(:port, nil)
          @transport = Transport.new(agent_hostname, port)

          # worker parameters
          @max_buffer_size = options.fetch(:buffer_size, 1000)
          @flush_interval = options.fetch(:flush_interval, 1)

          # traces metadata
          @service_name = options.fetch(:service, DEFAULT_SERVICE)

          # each processes have one worker thread
          @mutex_after_fork = Mutex.new
          @pid = nil
          @worker = nil
        end

        def start
          @pid = Process.pid
          @worker = Worker.new(@transport, @max_buffer_size, @flush_interval, @service_name)
          @worker.start()
        end

        def shutdown!
          return if @worker.nil?
          @worker.stop
        end

        def export(spans)
          return nil if spans.nil? || spans.empty?

          # create worker thread if not exist in this process
          pid = Process.pid
          if pid != @pid
            @mutex_after_fork.synchronize do
              start() if pid != @pid
            end
          end

          spans.each do |span|
            @worker.enqueue(span)
          end
        end
      end
    end
  end
end
