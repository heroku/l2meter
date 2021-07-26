require File.expand_path("../lib/l2meter/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name = "l2meter"
  spec.version = L2meter::VERSION
  spec.authors = ["Pavel Pravosud"]
  spec.email = ["pavel@pravosud.com"]

  spec.summary = "L2met friendly log formatter"
  spec.description = "L2meter is a tool for building logfmt-compatiable loggers."
  spec.homepage = "https://github.com/heroku/l2meter"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.8.0"
  spec.add_development_dependency "timecop"
end
