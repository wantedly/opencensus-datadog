require 'msgpack'

module OpenCensus
  module Trace
    module Exporters
      class Worker

        SHUTDOWN_TIMEOUT = 1

        def initialize(transport, max_buffer_size, flush_interval, service_name)
          @transport = transport
          @flush_interval = flush_interval
          @span_buffer = SpanBuffer.new(max_buffer_size)
          @converter = Converter.new(service_name)
          @shutdown = ConditionVariable.new
          @mutex = Mutex.new

          @worker = nil
          @run = false
        end

        def callback_spans
          return if @span_buffer.empty?

          begin
            spans = @span_buffer.pop()
            hash = Hash.new { |h, k| h[k] = [] }
            spans.each do |span|
              dd_span = @converter.convert_span(span)
              hash[dd_span[:trace_id]] << dd_span
            end
            traces = hash.map {|key,value| value}
            count = traces.length
            @transport.upload(MessagePack.pack(traces), count)
          rescue StandardError => e
            Datadog.log.error("[daatadog-exporter] failed to flush spans: #{e}")
          end
        end

        def start
          @mutex.synchronize do
            return if @run
            @run = true
            @worker = Thread.new { perform }
          end
        end

        def stop
          @mutex.synchronize do
            return unless @run
            @span_buffer.close
            @run = false
            @shutdown.signal
          end
          join
          true
        end

        def join
          @worker.join(SHUTDOWN_TIMEOUT)
        end

        def perform
          loop do
            start = Time.now
            callback_spans
            @mutex.synchronize do
              return if !@run && @span_buffer.empty?
              @shutdown.wait(@mutex, @flush_interval) if @run
            end
            Datadog.log.error("[datadog-exporter] worker-#{Process.pid} finished a iteration #{Time.now - start}")
          end
        end

        def enqueue(span)
          @span_buffer.push(span)
        end
      end
    end
  end
end
