require 'ddtrace/version'

if Gem::Version.new('1.0.0') <= Gem::Version.new(DDTrace::VERSION::STRING)
  require 'datadog/tracing/metadata/ext'
  require 'datadog/tracing/sampling/ext'
else
  require 'ddtrace/ext/distributed'
  require 'ddtrace/ext/priority'
  require 'ddtrace/ext/errors'
end

module OpenCensus
  module Trace
    module Exporters
      class Datadog
        class Converter

          DATADOG_MAX_TRACE_ID = 0xffff_ffff_ffff_ffff

          DATADOG_SPAN_TYPE_KEY = 'span.type'.freeze
          DATADOG_SERVICE_NAME_KEY = 'service.name'.freeze
          DATADOG_RESOURCE_NAME_KEY = 'resource.name'.freeze
          DATADOG_SAMPLING_PRIORITY_KEY = if defined?(::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY)
            ::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY
          else
            ::Datadog::Ext::DistributedTracing::SAMPLING_PRIORITY_KEY
          end

          STATUS_DESCRIPTION_KEY = 'opencensus.status_description'.freeze

          CANONICAL_CODES = [
            'ok',
            'cancelled',
            'unknown',
            'invalid_argument',
            'deadline_exceeded',
            'not_found',
            'already_exists',
            'permission_denied',
            'resource_exhausted',
            'failed_precondition',
            'aborted',
            'out_of_range',
            'unimplemented',
            'internal',
            'unavailable',
            'data_loss',
            'unauthenticated'
          ]

          def initialize(service)
            @service = service
          end

          def convert_span(span)
            dd_span = {
              span_id: span.span_id.to_i(16),
              parent_id: span.parent_span_id.to_i(16),
              trace_id: (span.trace_id.to_i(16) & DATADOG_MAX_TRACE_ID),
              name: span.name.to_s,
              service: @service,
              resource: span.name.to_s,
              type: span_type(span.kind.to_s),
              meta: {},
              metrics: {},
              error: 0,
              start: (span.start_time.to_f * 1e9).to_i,
              duration: ((span.end_time.to_f - span.start_time.to_f) * 1e9).to_i,
            }

            dd_span[:metrics][DATADOG_SAMPLING_PRIORITY_KEY] = if defined?(::Datadog::Tracing::Sampling::Ext::Priority::AUTO_KEEP)
              ::Datadog::Tracing::Sampling::Ext::Priority::AUTO_KEEP
            else
              ::Datadog::Ext::Priority::AUTO_KEEP
            end

            convert_status(dd_span, span.status)

            span.attributes.each do |k, v|
              case v
              when Integer
                if k == DATADOG_SAMPLING_PRIORITY_KEY
                  dd_span[:metrics][DATADOG_SAMPLING_PRIORITY_KEY] = v
                else
                  dd_span[:metrics][k] = v
                end
              when ::OpenCensus::Trace::TruncatableString
                case k
                when DATADOG_SPAN_TYPE_KEY
                  dd_span[:type] = v.to_s
                when DATADOG_SERVICE_NAME_KEY
                  dd_span[:service] = v.to_s
                when DATADOG_RESOURCE_NAME_KEY
                  dd_span[:resource] = v.to_s
                else
                  dd_span[:meta][k] = v.to_s
                end
              else
                dd_span[:meta][k] = v.to_s
              end
            end

            dd_span
          end

          def convert_status(dd_span, status)
            status_key = STATUS_DESCRIPTION_KEY
            return if status.nil?
            if status.code != 0 then
              status_key = if defined?(::Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG)
                ::Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG
              else
                ::Datadog::Ext::Errors::MSG
              end
              dd_span[:error] = 1
              code = status.code.to_i
              return if code < 0 || code >= CANONICAL_CODES.length
              dd_span[:meta][status_key] = CANONICAL_CODES[code]
            end
            dd_span[:meta][status_key] = status.message.to_s unless status.message.empty?
            return
          end

          def span_type(kind)
            case kind
            when OpenCensus::Trace::Span::SERVER
              'server'
            when OpenCensus::Trace::Span::CLIENT
              'client'
            else
              ''
            end
          end
        end
      end
    end
  end
end
