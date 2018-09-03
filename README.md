# Ruby Datadog APM Exporter for OpenCensus

This library is the implementation of [OpenCensus](https://census-instrumentation/opencensus-ruby) exporter that transfer metrics to [Datadog APM](https://www.datadoghq.com/apm/).
It is depending on Datadog Agent v6.

## Installation

Add `opencensus-datadog` to your application's Gemfile:

```ruby
gem 'opencensus-datadog'
```

And install the gem using Bundler:

```shell
$ bundle install
```

## Usage

Register this gem using OpenCensus configuration:


```ruby
OpenCensus.configure do |c|
  c.trace.exporter = OpenCensus::Trace::Integrations::Datadog.new
end
```

You can also use the following code if using Ruby on Rails:

```ruby
config.opencensus.trace.exporter = OpenCensus::Trace::Integrations::Datadog.new
```

By default, this gem sends metrics to the Datadog Agent at `http://localhost:8126`. You can send to different host or port.

```ruby
OpenCensus.configure do |c|
  c.trace.exporter = OpenCensus::Trace::Integrations::Datadog.new \
    agent_hostname: '192.168.1.1',
    agent_port: '1234'
end
```

## License

This project is releases under the [MIT License](https://opensource.org/licenses/MIT).
