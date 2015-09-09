# L2meter

L2meter is a little gem that helps you build loggers that outputs things in l2met format.

### Usage

```ruby
Metrics = L2meter.build do |config|
  # sort output tokens, false by default
  config.sort = true

  # default context
  config.context = { name: "my-app-name" }

  # ... or dynamic context
  config.context do
    { random_thing: SecureRandom.uuid }
  end

  # $stdout by default
  config.output = StringIO.new
end

Metrics.log "Hello world"                 # => hello-world

Metrics.log :foo, :bar, fizz: :buzz       # => foo bar fizz=buzz

Metrics.log :doing_work do                # => doing-work at=start
  do_some_work                            #
end                                       # => doing-work at=finish elapsed=3.1234s

Metrics.log :deez_nutz do                 # => deez-nutz at=start
  raise ArgumentError, "error here"       #
end                                       # => deez-nutz at=exception exception=ArgumentError message="error here" elapsed=1.2345s
```
