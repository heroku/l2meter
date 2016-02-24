# L2meter
[![Gem Version](https://img.shields.io/gem/v/l2meter.svg)](https://rubygems.org/gems/l2meter)
[![Build Status](https://img.shields.io/travis/rwz/l2meter.svg)](http://travis-ci.org/rwz/l2meter)
[![Code Climate](https://img.shields.io/codeclimate/github/rwz/l2meter.svg)](https://codeclimate.com/github/rwz/l2meter)

L2meter is a little gem that helps you build loggers that outputs things in
l2met-friendly format.

### Basics

A new logger might be created like so:

```ruby
Metrics = L2meter.build
```

If you plan to use it globally across different components of your app,consider
making it constant.

The base `log` method accepts two type of things: bare values and key-value
pairs in form of hashes.

```ruby
Metrics.log "Hello world"                 # => hello-world
Metrics.log :db_query, result: :success   # => db-query result=success
```

It can also take a block. In this case the message will be emitted twice, once
at the start of the execution and another at the end. The end result might look
like so:

```ruby
Metrics.log :doing_work do            # => doing-work at=start
  do_some_work                        #
  Metrics.log :work_done              # => work-done
end                                   # => doing-work at=finish elapsed=1.2345s
```

In case the exception is raised inside the block, l2meter will report is like
so:

```ruby
Metrics.log :doing_work do  # => doing-work at=start
  raise ArgumentError, \    #
    "something is wrong"    #
end                         # => doing-work at=exception exception=ArgumentError message="something is wrong" elapsed=1.2345s
```

## Context

L2meter allows setting context for a block. It might work something like this:

```ruby
def do_work_with_retries
  attempt = 1
  begin
    Metrics.context attempt: attempt do
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

The same example as above could be re-written like this instead:

```ruby
def do_work_with_retries
  attempt = 1
  Metrics.context ->{{ attempt: attempt }} do
    begin
      do_some_work
    rescue => error
      attempt +=1
      retry
    end
  end
end
```

## Other

Some other l2met-specific methods are supported.

```ruby
Metrics.count :user_registered             # => count#user-registered=1
Metrics.count :registered_users, 10        # => count#registered-users=10

Metrics.measure :connection_count, 20      # => measure#connection-count=20
Metrics.measure :db_query, 235, unit: :ms, # => measure#db-query.ms=235

Metrics.sample :connection_count, 20,      # => sample#connection-count=235
Metrics.sample :db_query, 235, unit: :ms,  # => sample#db-query.ms=235

Metrics.unique :user, "bob@example.com"    # => unique#user=bob@example.com
```

L2meter also allows to append elapsed time to your log messages automatically.

```ruby
Metrics.with_elapsed do
  do_work_step_1
  Metrics.log :step_1_done # => step-1-done elapsed=1.2345s
  do_work_step_2
  Metrics.log :step_2_done # => step-2-done elapsed=2.3456s
end
```

There's also a way to batch several calls into a single log line:

```ruby
Metrics.batch do
  Metrics.log foo: :bar
  Metrics.unique :registeration, "user@example.com"
  Metrics.count :thing, 10
  Metrics.sample :other_thing, 20
end # => foo=bar unique#registration=user@example.com count#thing=10 sample#other-thing=20
```

### Configuration

L2meter supports configuration. Here's how you can configure things:

```ruby
Metrics = L2meter.build do |config|
  # configuration happens here
end
```

Here's the list of all configurable things:

#### Global context

Global context works similary to context method, but globally:

```ruby
config.context = { app_name: "my-app-name" }

# ...

Metrics.log foo: :bar # => app-name=my-app-name foo-bar
```

Dynamic context is also supported:

```ruby
config.context do
  { request_id: CurrentContext.request_id }
end
```

#### Sorting

By default l2meter doesn't sort tokens before output, putting them in the order
they're passed. But you can make it sorted like so:

```ruby
config.sort = true

# ...

Metrics.log :c, :b, :a  # => a b c
```

#### Source

Source is a special parameter that'll be appended to all emitted messages.

```ruby
config.source = "production"

# ...

Metrics.log foo: :bar # => source=production foo=bar
```

#### Prefix

Prefix allows namespacing your measure/count/unique/sample calls.

```ruby
config.prefix = "my-app"

# ...

Metrics.count :users, 100500 # => count#my-app.users=100500
```

## Silence

There's a way to temporary silence the log emitter. This might be userful for
tests for example.

```ruby
Metrics.silence do
  # logger is completely silenced
  Metrics.log "hello world" # nothing is emitted here
end

# works normally again
Metrics.log :foo            # => foo
```

The typical setup for RSpec might look like this:

```ruby
RSpec.configure do |config|
  config.around :each do |example|
    Metrics.silence &example
  end
end
```

Note that this code will only silence logger in the current thread. It'll
still produce ouput if you fire up a new thread. To silence it completely,
use `disable!` method, like so:

```ruby
# spec/spec_helper.rb
Metrics.disable!
```
