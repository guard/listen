# Listen

[![Gem Version](https://badge.fury.io/rb/listen.png)](http://badge.fury.io/rb/listen) [![Build Status](https://travis-ci.org/guard/listen.png)](https://travis-ci.org/guard/listen) [![Dependency Status](https://gemnasium.com/guard/listen.png)](https://gemnasium.com/guard/listen) [![Code Climate](https://codeclimate.com/github/guard/listen.png)](https://codeclimate.com/github/guard/listen) [![Coverage Status](https://coveralls.io/repos/guard/listen/badge.png?branch=master)](https://coveralls.io/r/guard/listen)

The Listen gem listens to file modifications and notifies you about the changes.

## Features

* Supports watching multiple directories from a single listener.
* OS-specific adapters on MRI for Mac OS X 10.6+, Linux, *BSD and Windows, [more info](#listen-adapters) below.
* Detects file modification, addition and removal.
* Allows supplying regexp-patterns to ignore paths for better results.
* File content checksum comparison for modifications made under the same second (OS X only).
* Forwarding file events over TCP, [more info](#forwarding-file-events-over-tcp) below.
* Tested on MRI Ruby environments (1.9+ only) via [Travis CI](https://travis-ci.org/guard/listen),

Please note that:
- Specs suite on JRuby and Rubinius aren't reliable on Travis CI, but should work.
- Windows and *BSD adapter aren't continuously and automaticaly tested.

## Pending features

* Non-recursive directory scanning. [#111](https://github.com/guard/listen/issues/111)
* Symlinks support. [#25](https://github.com/guard/listen/issues/25)

Pull request or help is very welcome for these.

## Install

The simplest way to install Listen is to use [Bundler](http://bundler.io).

```ruby
gem 'listen', '~> 2.0'
```

## Usage

Call `Listen.to` with either a single directory or multiple directories, then define the "changes" callback in a block.

``` ruby
listener = Listen.to('dir/to/listen', 'dir/to/listen2') do |modified, added, removed|
  puts "modified absolute path: #{modified}"
  puts "added absolute path: #{added}"
  puts "removed absolute path: #{removed}"
end
listener.start # not blocking
sleep
```

### Pause / unpause / stop

Listeners can also be easily paused/unpaused:

``` ruby
listener = Listen.to('dir/path/to/listen') { |modified, added, removed| # ... }
listener.start
listener.listen? # => true
listener.pause   # stop listening to changes
listener.paused? # => true
listener.unpause # start listening to changes again
listener.stop    # stop completely the listener
```

  Note: You should keep track of all started listeners and stop them properly on finish.

### Ignore / ignore!

Listen ignores some directories and extensions by default (See DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in Listen::Silencer), you can add ignoring patterns with the `ignore` option/method or overwrite default with `ignore!` option/method.

``` ruby
listener = Listen.to('dir/path/to/listen', ignore: /\.txt/) { |modified, added, removed| # ... }
listener.start
listener.ignore! /\.pkg/ # overwrite all patterns and only ignore pkg extension.
listener.ignore /\.rb/   # ignore rb extension in addition of pkg.
sleep
```

Note: Ignoring regexp patterns are evaluated against relative paths.

### Only

Listen catches all files (less the ignored once) by default, if you want to only listen to a specific type of file (ie: just rb extension) you should use the `only` option/method.

``` ruby
listener = Listen.to('dir/path/to/listen', only: /\.rb$/) { |modified, added, removed| # ... }
listener.start
listener.only /_spec\.rb$/ # overwrite all existing only patterns.
sleep
```

Note: Only regexp patterns are evaluated only against relative **file** paths.

## Changes callback

Changes to the listened-to directories gets reported back to the user in a callback.
The registered callback gets invoked, when there are changes, with **three** parameters:
`modified`, `added` and `removed` paths, in that particular order.
Paths are always returned in their absolute form.

Example:

```ruby
listener = Listen.to('path/to/app') do |modified, added, removed|
  # This block will be called when there are changes.
end
listener.start
sleep
```

or ...

```ruby
# Create a callback
callback = Proc.new do |modified, added, removed|
  # This proc will be called when there are changes.
end
listener = Listen.to('dir', &callback)
listener.start
sleep
```

## Options

All the following options can be set through the `Listen.to` after the directory path(s) params.

```ruby
ignore: [%r{/foo/bar}, /\.pid$/, /\.coffee$/]   # Ignore a list of paths
                                                # default: See DEFAULT_IGNORED_DIRECTORIES and DEFAULT_IGNORED_EXTENSIONS in Listen::Silencer

ignore!: %r{/foo/bar}                           # Same as ignore options, but overwrite default ignored paths.

only: %r{.rb$}                                  # Only listen to specific files
                                                # default: none

latency: 0.5                                    # Set the delay (**in seconds**) between checking for changes
                                                # default: 0.25 sec (1.0 sec for polling)

wait_for_delay: 4                               # Set the delay (**in seconds**) between calls to the callback when changes exist
                                                # default: 0.10 sec

force_polling: true                             # Force the use of the polling adapter
                                                # default: none

polling_fallback_message: 'custom message'      # Set a custom polling fallback message (or disable it with false)
                                                # default: "Listen will be polling for changes. Learn more at https://github.com/guard/listen#polling-fallback."

debug: true                                     # Enable Celluloid logger
                                                # default: false
```

## Listen adapters

The Listen gem has a set of adapters to notify it when there are changes.
There are 4 OS-specific adapters to support Darwin, Linux, *BSD and Windows.
These adapters are fast as they use some system-calls to implement the notifying function.

There is also a polling adapter which is a cross-platform adapter and it will
work on any system. This adapter is slower than the rest of the adapters.

The Darwin and Linux adapters are dependencies of the Listen gem so they work out of the box. For other adapters a specific gem will have to be added to your Gemfile, please read below.

The Listen gem will choose the best adapter automatically, if present. If you
want to force the use of the polling adapter, use the `:force_polling` option
while initializing the listener.

### On Windows

If your are on Windows, you can try to use the [`wdm`](https://github.com/Maher4Ever/wdm) instead of polling.
Please add the following to your Gemfile:

```ruby
require 'rbconfig'
gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
```

### On *BSD

If your are on *BSD you can try to use the [`rb-kqueue`](https://github.com/mat813/rb-kqueue) instead of polling.
Please add the following to your Gemfile:

```ruby
require 'rbconfig'
gem 'rb-kqueue', '>= 0.2' if RbConfig::CONFIG['target_os'] =~ /freebsd/i
```

### Issues

Listen traps SIGINT signal to properly finalize listeners. If you plan
on trapping this signal yourself - make sure to call `Listen.stop` in
signal handler.

Sometimes OS-specific adapters don't work. :'(
Here are some things you could try to avoid forcing polling.

* [Update your Dropbox client](http://www.dropbox.com/downloading), if you have Dropbox installed.
* Move or rename the listened directory.
* Update/reboot your OS.
* Increase latency.
* If running Linux, check and see if you need package inotify-tools

If your application keeps using the polling-adapter and you can't figure out why, feel free to [open an issue](https://github.com/guard/listen/issues/new) (and be sure to [give all the details](https://github.com/guard/listen/blob/master/CONTRIBUTING.md)).

## Forwarding file events over TCP

Listen is capable of forwarding file events over the network using a messaging protocol. This can be useful for virtualized development environments when file events are unavailable, as is the case with [Vagrant](https://github.com/mitchellh/vagrant).

To broadcast events over TCP programmatically, use the `forward_to` option with an address - just a port or a hostname/port combination:

```ruby
listener = Listen.to 'path/to/app', forward_to: '10.0.0.2:4000' do |modified, added, removed|
  # After broadcasting the changes to any connected recipients,
  # this block will still be called
end
listener.start
sleep
```

As a convenience, the `listen` script is supplied which listens to a directory and forwards the events to a network address

```bash
listen -f "10.0.0.2:4000"
listen -v -d "/projects/my_project" -f "10.0.0.2:4000"
```

To connect to a broadcasting listener as a recipient, specify its address using `Listen.on`:

```ruby
listener = Listen.on '10.0.0.2:4000' do |modified, added, removed|
  # This block will be called
end
listener.start
sleep
```

### Security considerations

Since file events potentially expose sensitive information, care must be taken when specifying the broadcaster address. It is recommended to **always** specify a hostname and make sure it is as specific as possible to reduce any undesirable eavesdropping.

## Development

* Documentation hosted at [RubyDoc](http://rubydoc.info/github/guard/listen/master/frames).
* Source hosted at [GitHub](https://github.com/guard/listen).

Pull requests are very welcome! Please try to follow these simple rules if applicable:

* Please create a topic branch for every separate change you make.
* Make sure your patches are well tested. All specs must pass on [Travis CI](https://travis-ci.org/guard/listen).
* Update the [Yard](http://yardoc.org/) documentation.
* Update the [README](https://github.com/guard/listen/blob/master/README.md).
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

[Thibaud Guillaume-Gentil](https://github.com/thibaudgg) ([@thibaudgg](https://twitter.com/thibaudgg))

## Contributors

[https://github.com/guard/listen/graphs/contributors](https://github.com/guard/listen/graphs/contributors)

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
