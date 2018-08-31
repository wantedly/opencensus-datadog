module OpenCensus
  module Trace
    module Exporters
      class Datadog
        class SpanBuffer
          def initialize(max_size)
            @max_size = max_size
            @spans = []
            @mutex = Mutex.new()
            @closed = false
          end

          def push(span)
            @mutex.synchronize do
              return if @closed
              len = @spans.length
              if len < @max_size || @max_size <= 0
                return @spans << span
              else
                Datadog.log.error("[datadog-exporter] failed to write span into buffer due to exceeding by max buffer size")
              end
            end
          end

          def empty?
            @mutex.synchronize do
              return @spans.empty?
            end
          end

          def pop
            @mutex.synchronize do
              spans = @spans
              @spans = []
              return spans
            end
          end

          def close
            @mutex.synchronize do
              @closed = true
            end
          end
        end
      end
    end
  end
end
