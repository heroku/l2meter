# L2meter
[![Gem Version](https://img.shields.io/gem/v/l2meter.svg)](https://rubygems.org/gems/l2meter)
[![Build Status](https://img.shields.io/travis/heroku/l2meter.svg)](http://travis-ci.org/heroku/l2meter)
[![Code Climate](https://img.shields.io/codeclimate/github/heroku/l2meter.svg)](https://codeclimate.com/github/heroku/l2meter)

L2meter is a little gem that helps you build loggers that outputs things in
l2met-friendly format.

### Basics

A new logger might be created like so:

```ruby
metrics = L2meter.build
```

If you plan to use it globally across different components of your app,consider
making it constant.

The base `log` method accepts two type of things: bare values and key-value
pairs in form of hashes.

```ruby
metrics.log "Hello world"                 # => hello-world
metrics.log :db_query, result: :success   # => db-query result=success
```

It can also take a block. In this case the message will be emitted twice, once
at the start of the execution and another at the end. The end result might look
like so:

```ruby
metrics.log :doing_work do            # => doing-work at=start
  do_some_work                        #
  metrics.log :work_done              # => work-done
end                                   # => doing-work at=finish elapsed=1.2345s
```

In case the exception is raised inside the block, l2meter will report is like
so:

```ruby
metrics.log :doing_work do  # => doing-work
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
    metrics.context attempt: attempt do
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
value in porder to use it.

The same example as above could be written like ths instead:

```ruby
def do_work_with_retries
  attempt = 1
  metrics.context ->{{ attempt: attempt }} do
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
metrics.count :user_registered             # => count#user-registered=1
metrics.count :registered_users, 10        # => count#registered-users=10

metrics.measure :connection_count, 20,     # => measure#connection-count=235
metrics.measure :db_query, 235, unit: :ms, # => measure#db-query.ms=235

metrics.sample :connection_count, 20,      # => sample#connection-count=235
metrics.sample :db_query, 235, unit: :ms,  # => sample#db-query.ms=235

metrics.unique :user, "bob@example.com"    # => unique#user=bob@example.com
```

### Configuration

L2meter supports configurtion. Here's how you cna configure things:

```ruby
metrics = L2meter.build do |config|
  # configuration happen here
end
```

These are available configuration:

#### Global context

Global context works similary to context method, but globally:

```ruby
config.context = { app_name: "my-app-name" }

# ...

metrics.log foo: :bar # => app-name=my-app-name foo-bar
```

Dynamic context is also supported:

```ruby
context.context do
  { request_id: CurrentContext.request_id }
end
```

#### Sorting

By default l2meter doesn't sort tokens before output, putting them in the order
they're passed. But you can make it sorted like so:

```ruby
config.sort = true

# ...

metrics.log :c, :b, :a  # => a b c
```

#### Source

Source is a special parameter that'll be appended to all emitted messages.

```ruby
config.source = "production"

# ...

metrics.log foo: :bar # => source=production foo=bar
```

## Silence

There's a way to temporary silence the log emitter. This might be userful for
tests for example.

```ruby
metrics.silence do
  # logger is completely silenced
  metrics.log "hello world" # nothing is emitted here
end

# works normally again
metrics.log :foo            # => foo
```

The typical setup for RSpec might look like this:

```ruby
RSpec.configure do |config|
  config.around :each do |example|
    Metrics.silence &example
  end
end
```
