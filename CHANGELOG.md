# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CHANGELOG.md

### Changed
- Officially only support Ruby 2.5+; all older Rubies are EoL'd.

### Fixed
- Fix Ruby 2.7 proc warning
- Fix Ruby 2.7 last argument as keyword params warning

## [0.13.0] 2019-05-11

### Changed
- Total re-write to fix memory leaks in `L2meter::ThreadSafe` proxy object. See: https://github.com/heroku/l2meter/issues/6
