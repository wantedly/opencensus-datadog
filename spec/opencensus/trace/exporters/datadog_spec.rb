require 'spec_helper'

describe OpenCensus::Trace::Exporters::Datadog do
  describe '.log' do
    it 'uses default logger' do
      expect(OpenCensus::Trace::Exporters::Datadog.log.level).to eq ::Logger::WARN
    end
  end
end
