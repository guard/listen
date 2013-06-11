# Listen [![Gem Version](https://badge.fury.io/rb/listen.png)](http://badge.fury.io/rb/listen) [![Build Status](https://secure.travis-ci.org/guard/listen.png?branch=master)](http://travis-ci.org/guard/listen) [![Dependency Status](https://gemnasium.com/guard/listen.png)](https://gemnasium.com/guard/listen) [![Code Climate](https://codeclimate.com/github/guard/listen.png)](https://codeclimate.com/github/guard/listen) [![Coverage Status](https://coveralls.io/repos/guard/listen/badge.png?branch=master)](https://coveralls.io/r/guard/listen)

The Listen gem listens to file modifications and notifies you about the changes.

## WARNING

The `v2.0` branch is a work in progress and doesn't work as the moment!

## Features

* Works everywhere!
* Supports watching multiple directories from a single listener.
* OS-specific adapters for Mac OS X 10.6+, Linux, *BSD and Windows.
* Detects file modification, addition and removal.
* Checksum comparison for modifications made under the same second.
* Tested on all Ruby environments (1.9+ only) via [Travis CI](https://travis-ci.org/guard/listen).

# TODO

* Allows supplying regexp-patterns to ignore and filter paths for better results.
* Automatic fallback to polling if OS-specific adapter doesn't work.

## Install

### Using Bundler

The simplest way to install Listen is to use Bundler.

Add Listen to your Gemfile:

```ruby
group :development do
  gem 'listen'
end
```

and install it by running Bundler:

```bash
$ bundle
```

### Install the gem with RubyGems

```bash
$ gem install listen
```

## Usage

Call `Listen.to``with either a single directory or multiple directories, then define the `change` callback in a block.

``` ruby
# Listen to a single directory.
listener = Listen.to('dir/path/to/listen') do |modified, added, removed|
  puts "modified path: #{modified}"
  puts "added path: #{added}"
  puts "removed path: #{removed}"
end
listener.start # not blocking
sleep
```

or...

``` ruby
# Listen to multiple directories.
listener = Listen.to('dir/to/awesome_app', 'dir/to/other_app') do |modified, added, removed|
  puts "modified path: #{modified}"
  puts "added path: #{added}"
  puts "removed path: #{removed}"
end
listener.start # not blocking
sleep
```

### Pause/Unpause/Stop

Listener can also easily be paused/unpaused:

``` ruby
listener = Listen.to('dir/path/to/listen') { |modified, added, removed| # ... }
listener.start
listener.pause   # stop listening to changes
listener.paused? # => true
listener.unpause # start listening to changes again
listener.stop    # stop completely the listener
```

## Changes callback

Changes to the listened-to directories gets reported back to the user in a callback.
The registered callback gets invoked, when there are changes, with **three** parameters:
`modified_paths`, `added_paths` and `removed_paths` in that particular order.

Example:

```ruby
listener = Listen.to('path/to/app') do |modified, added, removed|
  # This block will be called when there are changes.
end
listener.start # not blocking
sleep
# or ...

```ruby
# Create a callback
callback = Proc.new do |modified, added, removed|
  # This proc will be called when there are changes.
end
listener = Listen.to('dir', &callback)
listener.start # not blocking
sleep
```

### Paths in callbacks

Listeners invoke callbacks passing them absolute paths:

```ruby
# Assume someone changes the 'style.css' file in '/home/user/app/css' after creating
# the listener.
listener = Listen.to('/home/user/app/css') do |modified, added, removed|
  modified.inspect # => ['/home/user/app/css/style.css']
end
listener.start # not blocking
sleep
```

## Options

All the following options can be set through the `Listen.to` after the path(s) params.

```ruby
ignore: %r{app/CMake/}, /\.pid$/   # Ignore a list of paths (root directory or sub-dir)
                                   # default: See DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in Listen::DirectoryRecord

ignore!: # TODO

filter: /\.rb$/, /\.coffee$/               # Filter files to listen to via a regexps list.
                                              # default: none
filter!: # TODO

latency: 0.5                               # Set the delay (**in seconds**) between checking for changes
                                              # default: 0.25 sec (1.0 sec for polling)

force_adapter: Listen::Adapter::Darwin   # TODO

force_polling: true                        # Force the use of the polling adapter
                                              # default: none


polling_fallback_message: 'custom message' # Set a custom polling fallback message (or disable it with false)
                                              # default: "Listen will be polling for changes. Learn more at https://github.com/guard/listen#polling-fallback."
```

### Note on the patterns for ignoring and filtering paths

Just like the unix convention of beginning absolute paths with the
directory-separator (forward slash `/` in unix) and with no prefix for relative paths,
Listen doesn't prefix relative paths (to the watched directory) with a directory-separator.

Therefore make sure _NOT_ to prefix your regexp-patterns for filtering or ignoring paths
with a directory-separator, otherwise they won't work as expected.

As an example: to ignore the `build` directory in a C-project, use `%r{build/}`
and not `%r{/build/}`.

Use `:filter!` and `:ignore!` options to overwrites default patterns.

## Listen adapters

The Listen gem has a set of adapters to notify it when there are changes.
There are 4 OS-specific adapters to support Mac, Linux, *BSD and Windows.
These adapters are fast as they use some system-calls to implement the notifying function.

There is also a polling adapter which is a cross-platform adapter and it will
work on any system. This adapter is slower than the rest of the adapters.

The Listen gem will choose the best and working adapter for your machine automatically. If you
want to force the use of the polling adapter, either use the `:force_polling` option
while initializing the listener or call the `#force_polling` method on your listener
before starting it.

### On Windows

If your are on Windows you can try to use the [`wdm`](https://github.com/Maher4Ever/wdm) instead of polling.
Please add the following to your Gemfile:

```ruby
require 'rbconfig'
gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i
```

## Polling fallback

When a OS-specific adapter doesn't work the Listen gem automatically falls back to the polling adapter.
Here are some things you could try to avoid the polling fallback:

* [Update your Dropbox client](http://www.dropbox.com/downloading) (if used).
* Move or rename the listened folder.
* Update/reboot your OS.
* Increase latency.

If your application keeps using the polling-adapter and you can't figure out why, feel free to [open an issue](https://github.com/guard/listen/issues/new) (and be sure to [give all the details](https://github.com/guard/listen/blob/master/CONTRIBUTING.md)).

## Development [![Dependency Status](https://gemnasium.com/guard/listen.png?branch=master)](https://gemnasium.com/guard/listen)

* Documentation hosted at [RubyDoc](http://rubydoc.info/github/guard/listen/master/frames).
* Source hosted at [GitHub](https://github.com/guard/listen).

Pull requests are very welcome! Please try to follow these simple rules if applicable:

* Please create a topic branch for every separate change you make.
* Make sure your patches are well tested. All specs must pass on [Travis CI](https://travis-ci.org/guard/listen).
* Update the [Yard](http://yardoc.org/) documentation.
* Update the [README](https://github.com/guard/listen/blob/master/README.md).
* Update the [CHANGELOG](https://github.com/guard/listen/blob/master/CHANGELOG.md) for noteworthy changes (don't forget to run `bundle exec pimpmychangelog` and watch the magic happen)!
* Please **do not change** the version number.

For questions please join us in our [Google group](http://groups.google.com/group/guard-dev) or on
`#guard` (irc.freenode.net).

## Acknowledgments

* [Michael Kessler (netzpirat)][] for having written the [initial specs](https://github.com/guard/listen/commit/1e457b13b1bb8a25d2240428ce5ed488bafbed1f).
* [Travis Tilley (ttilley)][] for this awesome work on [fssm][] & [rb-fsevent][].
* [Nathan Weizenbaum (nex3)][] for [rb-inotify][], a thorough inotify wrapper.
* [Mathieu Arnold (mat813)][] for [rb-kqueue][], a simple kqueue wrapper.
* [Maher Sallam][] for [wdm][], windows support wouldn't exist without him.
* [Yehuda Katz (wycats)][] for [vigilo][], that has been a great source of inspiration.

## Author

* [Thibaud Guillaume-Gentil (thibaudgg)][] ([@thibaudgg](http://twitter.com/thibaudgg))

## Contributors

[https://github.com/guard/listen/contributors](https://github.com/guard/listen/contributors)

[Thibaud Guillaume-Gentil (thibaudgg)]: https://github.com/thibaudgg
[Maher Sallam]: https://github.com/Maher4Ever
[Michael Kessler (netzpirat)]: https://github.com/netzpirat
[Travis Tilley (ttilley)]: https://github.com/ttilley
[fssm]: https://github.com/ttilley/fssm
[rb-fsevent]: https://github.com/thibaudgg/rb-fsevent
[Mathieu Arnold (mat813)]: https://github.com/mat813
[Nathan Weizenbaum (nex3)]: https://github.com/nex3
[rb-inotify]: https://github.com/nex3/rb-inotify
[stereobooster]: https://github.com/stereobooster
[rb-fchange]: https://github.com/stereobooster/rb-fchange
[rb-kqueue]: https://github.com/mat813/rb-kqueue
[Yehuda Katz (wycats)]: https://github.com/wycats
[vigilo]: https://github.com/wycats/vigilo
[wdm]: https://github.com/Maher4Ever/wdm
