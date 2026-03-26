require 'spec_helper'

describe OpenCensus::Trace::Exporters::Datadog::Converter do
  let(:converter) { described_class.new('test-service') }
  let(:trace_id) { 'fedcba98765432100123456789abcdef' }
  let(:span_id) { '0123456789abcdef' }
  let(:parent_span_id) { 'fedcba9876543210' }
  let(:start_time) { Time.utc(2025, 1, 1, 0, 0, 0) }
  let(:end_time) { Time.utc(2025, 1, 1, 0, 0, 2) }
  let(:span) do
    OpenCensus::Trace::Span.new(
      trace_id,
      span_id,
      OpenCensus::Trace::TruncatableString.new('test.operation'),
      start_time,
      end_time,
      kind: OpenCensus::Trace::Span::SERVER,
      parent_span_id: parent_span_id,
      status: OpenCensus::Trace::Status.new(0, ''),
      attributes: {}
    )
  end

  describe '#convert_span' do
    it 'converts basic span fields' do
      result = converter.convert_span(span)

      expect(result[:span_id]).to eq(span_id.to_i(16))
      expect(result[:parent_id]).to eq(parent_span_id.to_i(16))
      expect(result[:trace_id]).to eq(trace_id.to_i(16) & 0xffff_ffff_ffff_ffff)
      expect(result[:name]).to eq('test.operation')
      expect(result[:service]).to eq('test-service')
      expect(result[:resource]).to eq('test.operation')
      expect(result[:type]).to eq('server')
      expect(result[:error]).to eq(0)
    end

    it 'converts timestamps to nanoseconds' do
      result = converter.convert_span(span)

      expect(result[:start]).to eq((start_time.to_f * 1e9).to_i)
      expect(result[:duration]).to eq(2_000_000_000)
    end

    it 'sets default sampling priority to AUTO_KEEP' do
      result = converter.convert_span(span)
      sampling_key = ::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY

      expect(result[:metrics][sampling_key]).to eq(
        ::Datadog::Tracing::Sampling::Ext::Priority::AUTO_KEEP
      )
    end

    it 'sets type to client for CLIENT kind' do
      client_span = OpenCensus::Trace::Span.new(
        trace_id, span_id,
        OpenCensus::Trace::TruncatableString.new('client.call'),
        start_time, end_time,
        kind: OpenCensus::Trace::Span::CLIENT,
        status: OpenCensus::Trace::Status.new(0, ''),
        attributes: {}
      )
      result = converter.convert_span(client_span)

      expect(result[:type]).to eq('client')
    end

    context 'with error status' do
      let(:error_span) do
        OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(13, ''),
          attributes: {}
        )
      end

      it 'sets error flag and canonical code' do
        result = converter.convert_span(error_span)
        error_key = ::Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG

        expect(result[:error]).to eq(1)
        expect(result[:meta][error_key]).to eq('internal')
      end

      it 'uses status message when present' do
        span_with_msg = OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(13, 'something went wrong'),
          attributes: {}
        )
        result = converter.convert_span(span_with_msg)
        error_key = ::Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG

        expect(result[:meta][error_key]).to eq('something went wrong')
      end
    end

    context 'with attributes' do
      it 'maps Integer attributes to metrics' do
        span_with_attrs = OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(0, ''),
          attributes: { 'http.status_code' => 200 }
        )
        result = converter.convert_span(span_with_attrs)

        expect(result[:metrics]['http.status_code']).to eq(200)
      end

      it 'maps TruncatableString attributes to meta' do
        span_with_attrs = OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(0, ''),
          attributes: { 'http.method' => OpenCensus::Trace::TruncatableString.new('GET') }
        )
        result = converter.convert_span(span_with_attrs)

        expect(result[:meta]['http.method']).to eq('GET')
      end

      it 'overrides span type, service, and resource with special keys' do
        span_with_attrs = OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(0, ''),
          attributes: {
            'span.type' => OpenCensus::Trace::TruncatableString.new('web'),
            'service.name' => OpenCensus::Trace::TruncatableString.new('custom-service'),
            'resource.name' => OpenCensus::Trace::TruncatableString.new('/api/users')
          }
        )
        result = converter.convert_span(span_with_attrs)

        expect(result[:type]).to eq('web')
        expect(result[:service]).to eq('custom-service')
        expect(result[:resource]).to eq('/api/users')
      end

      it 'overrides sampling priority with Integer attribute' do
        sampling_key = ::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY
        span_with_attrs = OpenCensus::Trace::Span.new(
          trace_id, span_id,
          OpenCensus::Trace::TruncatableString.new('test.operation'),
          start_time, end_time,
          kind: OpenCensus::Trace::Span::SERVER,
          status: OpenCensus::Trace::Status.new(0, ''),
          attributes: { sampling_key => 2 }
        )
        result = converter.convert_span(span_with_attrs)

        expect(result[:metrics][sampling_key]).to eq(2)
      end
    end
  end
end
