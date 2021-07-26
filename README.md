# L2meter
[![Gem Version](https://img.shields.io/gem/v/l2meter.svg)](https://rubygems.org/gems/l2meter)
[![CI Status](https://github.com/heroku/l2meter/actions/workflows/ci.yml/badge.svg)](https://github.com/heroku/l2meter/actions/workflows/ci.yml)

L2meter is a little gem for building [logfmt]-compatiable loggers.

[logfmt]: https://www.brandur.org/logfmt

### Basics

A new logger might be created like so:

```ruby
logger = L2meter.build
```

Consider making the logger a constant to make it easier to use across different
components of the app or globally.

The base `log` method accepts two type of arguments: bare values and key-value
pairs in form of hashes.

```ruby
logger.log "Hello world"                 # => hello-world
logger.log :db_query, result: :success   # => db-query result=success
```

The method also takes a block. In this case the message will be emitted twice,
once at the start of the execution and once at the end. The end result might
look like so:

```ruby
logger.log :doing_work do            # => doing-work at=start
  do_some_work                       #
  logger.log :work_done              # => work-done
end                                  # => doing-work at=finish elapsed=1.2345
```

In case of an exception inside the block, all relevant information is logged
and then the exception is re-raised.

```ruby
logger.log :doing_work do   # => doing-work at=start
  raise ArgumentError, \    #
    "something is wrong"    #
end                         # => doing-work at=exception exception=ArgumentError message="something is wrong" elapsed=1.2345
                            # ArgumentError: something is wrong
```

## Context

L2meter allows setting context for a block. It might work something like this:

```ruby
def do_work_with_retries
  attempt = 1
  begin
    logger.context attempt: attempt do
      do_some_work            # => doing-work attempt=1
                              # => doing-work attempt=2
                              # => doing-work attempt=3
    end
  rescue => error
    attempt += 1
    retry
  end
end
```

L2meter supports dynamic contexts as well. You can pass a proc instead of raw
value in order to use it.

The example above could be re-written like this instead:

```ruby
def do_work_with_retries
  attempt = 1
  logger.context ->{{ attempt: attempt }} do
    begin
      do_some_work
    rescue => error
      attempt +=1
      retry
    end
  end
end
```

It's possible to create a dedicated copy of the logger with some specific
context attached to it.

```ruby
worker_logger = logger.context(component: :worker, worker_id: 123)

MyWorker.new(logger: worker_logger).run # => component=worker worker_id=123 status="doing work"
```

## Batching

There's a way to batch several calls into a single log line:

```ruby
logger.batch do
  logger.log foo: :bar
  logger.unique :registration, "user@example.com"
  logger.count :thing, 10
  logger.sample :other_thing, 20
end # => foo=bar unique#registration=user@example.com count#thing=10 sample#other-thing=20
```

## Metrics

Some [l2met]-specific metrics are supported.

[l2met]: https://r.32k.io/l2met-introduction

```ruby
logger.count :user_registered             # => count#user-registered=1
logger.count :registered_users, 10        # => count#registered-users=10

logger.measure :connection_count, 20      # => measure#connection-count=20
logger.measure :db_query, 235, unit: :ms, # => measure#db-query.ms=235

logger.sample :connection_count, 20,      # => sample#connection-count=235
logger.sample :db_query, 235, unit: :ms,  # => sample#db-query.ms=235

logger.unique :user, "bob@example.com"    # => unique#user=bob@example.com
```

## Measuring Time

L2meter allows to append elapsed time to log messages automatically.

```ruby
logger.with_elapsed do
  do_work_step_1
  logger.log :step_1_done # => step-1-done elapsed=1.2345
  do_work_step_2
  logger.log :step_2_done # => step-2-done elapsed=2.3456
end
```

## Configuration

L2meter supports customizable configuration.

```ruby
logger = L2meter.build do |config|
  # configuration happens here
end
```

Here's the full list of available settings.

### Global context

Global context works similarly to context method, but globally:

```ruby
config.context = { app_name: "my-app-name" }

# ...

logger.log foo: :bar # => app-name=my-app-name foo=bar
```

Dynamic context is also supported:

```ruby
config.context do
  { request_id: SecureRandom.uuid }
end

logger.log :hello # => hello request_id=4209ba28-4a7c-40d6-af69-c2c1ddf51f19
logger.log :world # => world request_id=b6836b1b-5710-4f5f-926d-91ab9988a7c1
```

### Sorting

By default l2meter doesn't sort tokens before output, putting them in the order
they're passed. But it's possible to sort them like so:

```ruby
config.sort = true

# ...

logger.log :c, :b, :a  # => a b c
```

### Source

Source is a special parameter that'll be appended to all emitted messages.

```ruby
config.source = "com.heroku.my-application.staging"

# ...

logger.log foo: :bar # => source=com.heroku.my-application.staging foo=bar
```

### Prefix

Prefix allows to add namespacing to measure/count/unique/sample calls.

```ruby
config.prefix = "my-app"

# ...

logger.count :users, 100500 # => count#my-app.users=100500
```

### Scrubbing

L2meter allows plugging in custom scrubbing logic that might be useful in
environments where logging compliance is important to prevent accidentally
leaking sensitive information.

```ruby
config.scrubber = -> (key, value) do
  begin
    uri = URI.parse(value)
    uri.password = "redacted" if uri.password
    uri.to_s
  rescue URI::Error
    value
  end
end

logger.log my_url: "https://user:password@example.com"
# => my-url="https://user:redacted@example.com"
```

Note that returning nil value will make l2meter omit the field completely.

### "Compacting" values

By default l2meter will treat key-value pairs where the value is `true`, `false` or `nil` differently. `false` and `nil` values will cause the whole pair to be omitted, `true` will cause just the key to be output:

```ruby
logger.log foo: "hello", bar: true  # => foo=hello bar
logger.log foo: "hello", bar: false # => foo=hello
logger.log foo: "hello", bar: nil   # => foo=hello
```

When the option is disabled, the full pairs are emitted:

```ruby
config.compact_values = false
logger.log foo: "hello", bar: true  # => foo=hello bar=true
logger.log foo: "hello", bar: false # => foo=hello bar=false
logger.log foo: "hello", bar: nil   # => foo=hello bar=null
```

Note that "null" is output in the `nil` case.

## Silence

There's a way to temporary silence the log emitter. This might be useful for
tests for example.

```ruby
logger.silence do
  # logger is completely silenced
  logger.log "hello world" # nothing is emitted here
end

# works normally again
logger.log :foo            # => foo
```

The typical setup for RSpec might look like this:

```ruby
RSpec.configure do |config|
  config.around :each do |example|
    MyLogger.silence &example
  end
end
```

Note that silence method will only suppress logging in the current thread.
It'll still produce output if you fire up a new thread. To silence it
completely, use `disable!` method. This will completely silence the logger
across all threads.

```ruby
# spec/spec_helper.rb
MyLogger.disable!
```
