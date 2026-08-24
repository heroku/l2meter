# Contributing to L2meter

## Governance Model

L2meter is published but not supported. It is open sourced to share useful code
and concepts, but the maintainers do not solicit contributions and may not
review issues or pull requests promptly. The maintainers decide whether to
accept a contribution.

## Reporting Issues

Use [GitHub Issues](https://github.com/heroku/l2meter/issues) to report a bug
or share an idea. Include a clear description and, for bugs, steps to reproduce
the behavior when possible.

## Pull Requests

If you choose to contribute, open a pull request against the `main` branch.
Keep the change focused and include tests when the change affects behavior.

Before opening a pull request, run:

```sh
bundle install
bundle exec rspec
gem build l2meter.gemspec
```

## Contributor License Agreement

To accept a pull request, Salesforce requires a signed Contributor License
Agreement (CLA). You only need to sign it once for Salesforce open source
projects: <https://cla.salesforce.com/sign-cla>.

## Code of Conduct

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree to license your contribution under the terms of the
project [license](LICENSE.txt) and to sign the Salesforce CLA.
