require 'spec_helper'

describe OpenCensus::Trace::Exporters::Datadog do
  describe '.log' do
    it 'uses default logger' do
      expect(OpenCensus::Trace::Exporters::Datadog.log.level).to eq ::Logger::WARN
    end
  end

  describe 'Datadog gem constants compatibility' do
    let(:converter) { OpenCensus::Trace::Exporters::Datadog::Converter.new('test-service') }

    it 'has access to TAG_SAMPLING_PRIORITY constant' do
      expect(::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY).to be_a(String)
      expect(OpenCensus::Trace::Exporters::Datadog::Converter::DATADOG_SAMPLING_PRIORITY_KEY).to eq(
        ::Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY
      )
    end

    it 'has access to Priority::AUTO_KEEP constant' do
      expect(::Datadog::Tracing::Sampling::Ext::Priority::AUTO_KEEP).to be_a(Integer)
    end

    it 'has access to Errors::TAG_MSG constant' do
      expect(::Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG).to be_a(String)
    end
  end
end
