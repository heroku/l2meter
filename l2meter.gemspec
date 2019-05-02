require File.expand_path("../lib/l2meter/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name         = "l2meter"
  spec.version      = L2meter::VERSION
  spec.authors      = ["Pavel Pravosud"]
  spec.email        = ["pavel@pravosud.com"]
  spec.summary      = "L2met friendly log formatter"
  spec.homepage     = "https://github.com/heroku/l2meter"
  spec.license      = "MIT"
  spec.files        = Dir["LICENSE.txt", "README.md", "lib/**/**"]
  spec.require_path = "lib"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.8.0"
  spec.add_development_dependency "timecop"
end
