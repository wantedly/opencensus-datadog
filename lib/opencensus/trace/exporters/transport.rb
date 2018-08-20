require 'net/http'

module OpenCensus
  module Trace
    module Exporters
      class Transport
        DEFAULT_HOSTNAME = '127.0.0.1'.freeze
        DEFAULT_PORT = '8126'.freeze

        TRACE_ENDPOINT = '/v0.4/traces'.freeze
        TIMEOUT = 5

        TRACE_COUNT_HEADER = 'X-Datadog-Trace-Count'.freeze
        RUBY_INTERPRETER = RUBY_VERSION > '1.9' ? RUBY_ENGINE + '-' + RUBY_PLATFORM : 'ruby-' + RUBY_PLATFORM
        TRACER_VERSION = 'OC/' + OpenCensus::Datadog::VERSION

        def initialize(hostname, port)
          @hostname = hostname.nil? ? DEFAULT_HOSTNAME : hostname
          @port = port.nil? ? DEFAULT_PORT : port

          @headers = {}
          @headers['Datadog-Meta-Lang'] = 'ruby'
          @headers['Datadog-Meta-Lang-Version'] = RUBY_VERSION
          @headers['Datadog-Meta-Lang-Interpreter'] = RUBY_INTERPRETER
          @headers['Datadog-Meta-Tracer-Version'] = TRACER_VERSION
          @headers['Content-Type'] = 'application/msgpack'
        end

        def upload(data, count = nil)
          begin
            headers = count.nil? ? {} : { TRACE_COUNT_HEADER => count.to_s }
            headers = headers.merge(@headers)
            request = Net::HTTP::Post.new(TRACE_ENDPOINT, headers)
            request.body = data

            response = Net::HTTP.start(@hostname, @port, read_timeout: TIMEOUT) { |http| http.request(request) }

            status_code = response.code.to_i
            if status_code >= 400 then
              Datadog.log.error("[daatadog-exporter] #{response.message} (status: #{status_code})")
            end
            status_code
          rescue StandardError => e
            Datadog.log.error("[daatadog-exporter] failed HTTP request to agent: #{e.message}")
            500
          end
        end
      end
    end
  end
end
