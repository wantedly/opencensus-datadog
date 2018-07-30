require 'ddtrace/ext/distributed'
require 'ddtrace/ext/priority'
require 'ddtrace/ext/errors'
require 'opencensus'

module OpenCensus
  module Trace
    module Exporters
      class Converter

        DATADOG_MAX_TRACE_ID = 0xffff_ffff_ffff_ffff

        STATUS_DESCRIPTION_KEY = 'opencensus.status_description'.freeze

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

          dd_span[:metrics][::Datadog::Ext::DistributedTracing::SAMPLING_PRIORITY_KEY] = ::Datadog::Ext::Priority::AUTO_KEEP

          convert_status(dd_span, span.status)

          span.attributes.each do |k, v|
            dd_span[:meta][k] = v.to_s
          end
          dd_span
        end

        def convert_status(dd_span, status)
          status_key = STATUS_DESCRIPTION_KEY
          return if status.nil?
          if status.code >= 400 then
            status_key = ::Datadog::Ext::Errors::MSG
            dd_span[:error] = 1
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
