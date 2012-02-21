# Listen [![Build Status](https://secure.travis-ci.org/guard/listen.png?branch=master)](http://travis-ci.org/guard/listen)

The Listen gem listens to file modifications and notifies you about the changes.

## Features

* Works everywhere!
* OS-specific adapters for Mac OS X 10.6+, Linux and Windows.
* Automatic fallback to polling if OS-specific adapter doesn't work.
* Detects files modification, addidation and removal.
* Checksum comparaison for modifications made under the same second.
* Tested on all Ruby environments via [travis-ci](http://travis-ci.org/guard/listen).
* Threadable.

## Install

``` bash
gem install listen
```

## Usage

There are two ways you can use Listen.

1. call `Listen.to` with a path params, and define callbacks in a block.
2. create a `listener` object usable in an (ARel style) chainable way.

Feel free to give your feeback via [Listen issues](https://github.com/guard/listener/issues)

### Block API

``` ruby
Listen.to('dir/path/to/listen', filter: /.*\.rb/, ignore: '/ignored/path') do |modified, added, removed|
  # ...
end
```

### "Object" API

``` ruby
listener = Listen.to('dir/path/to/listen')
listener = listener.ignore('/ignored/path')
listener = listener.filter(/.*\.rb/)
listener = listener.latency(0.5)
listener = listener.force_polling(true)
listener = listener.polling_fallback_message(false)
listener = listener.change(&callback)
listener.start # enter the run loop
listener.stop
```

#### Chainable

``` ruby
Listen.to('dir/path/to/listen')
      .ignore('/ignored/path')
      .filter(/.*\.rb/)
      .latency(0.5)
      .force_polling(true)
      .polling_fallback_message('custom message')
      .change(&callback)
      .start # enter the run loop
```

#### Multiple listeners support available via Thread

``` ruby
listener = Listen.to(dir1).ignore('/ignored/path/')
styles   = listener.filter(/.*\.css/).change(&style_callback)
scripts  = listener.filter(/.*\.js/).change(&scripts_callback)

Thread.new { styles.start } # enter the run loop
Thread.new { scripts.start } # enter the run loop
```

### Options

These options can be set through `Listen.to` params or via methods (see the "Object" API)

```ruby
:filter => /.*\.rb/, /.*\.coffee/              # Filter files to listen to via a regexps list.
                                               # default: none

:ignore => 'path1', 'path2'                    # Ignore a list of paths (root directory or sub-dir)
                                               # default: '.bundle', '.git', '.DS_Store', 'log', 'tmp', 'vendor'

:latency => 0.5                                # Set the delay (**in seconds**) between checking for changes
                                               # default: 0.1 sec (1.0 sec for polling)

:force_polling => true                         # Force the use of the polling adapter
                                               # default: none

:polling_fallback_message => 'custom message'  # Set a custom polling fallback message (or disable it with `false`)
                                               # default: "WARNING: Listen fallen back to polling, learn more at https://github.com/guard/listen."
```

## Listen adapters

The Listen gem has a set of adapters to notify it when there are changes.
There are 3 OS-specific adapters to support Mac, Linux and Windows. These adapters are fast
as they use some system-calls to implement the notifying function.

There is also a polling adapter which is a cross-platform adapter and it will
work on any system. This adapter is unfortunately slower than the rest of the adapters.

The Listen gem will choose the best and working adapter for your machine automatically. If you
want to force the use of the polling adapter, either use the `:force_polling` option
while initializing the listener or call the `force_polling` method on your listener
before starting it.

### Polling fallback
<a id="fallback"/>

When the OS-specific adapter doesn't work the Listen gem automatically falls back to the polling adapter.
Here some things to try to avoiding this fallback:

* [Update your Dropbox client](http://www.dropbox.com/downloading) (if used).
* Move or rename the listened folder.
* Update/reboot your OS.

If it still falling back, feel free to [open an issue](https://github.com/guard/listen/issues/new) (and be sure to give all details).

## Development [![Dependency Status](https://gemnasium.com/guard/listen.png?branch=master)](https://gemnasium.com/guard/listen)

* Documentation hosted at [RubyDoc](http://rubydoc.info/github/guard/listen/master/frames).
* Source hosted at [GitHub](https://github.com/guard/listen).

Pull requests are very welcome! Please try to follow these simple rules if applicable:

* Please create a topic branch for every separate change you make.
* Make sure your patches are well tested. All specs run with `rake spec:portability` must pass.
* Update the [Yard](http://yardoc.org/) documentation.
* Update the README.
* Update the CHANGELOG for noteworthy changes.
* Please **do not change** the version number.

For questions please join us in our [Google group](http://groups.google.com/group/guard-dev) or on
`#guard` (irc.freenode.net).

## Acknowledgment

* [Michael Kessler (netzpirat)][] for having written the [initial specs](https://github.com/guard/listen/commit/1e457b13b1bb8a25d2240428ce5ed488bafbed1f).
* [Travis Tilley (ttilley)][] for this awesome work on [fssm][] & [rb-fsevent][].
* [Nathan Weizenbaum (nex3)][] for [rb-inotify][], a thorough inotify wrapper.
* [stereobooster][] for [rb-fchange][], windows support wouldn't exist without him.
* [Yehuda Katz (wycats)][] for [vigilo][], that has been a great source of inspiration.

## Author

[Thibaud Guillaume-Gentil][] ([@thibaudgg](http://twitter.com/thibaudgg))

## Contributors

[https://github.com/guard/listen/contributors](https://github.com/guard/listen/contributors)

[Thibaud Guillaume-Gentil]: https://github.com/thibaudgg
[Michael Kessler (netzpirat)]: https://github.com/netzpirat
[Travis Tilley (ttilley)]: https://github.com/ttilley
[fssm]: https://github.com/ttilley/fssm
[rb-fsevent]: https://github.com/thibaudgg/rb-fsevent
[Nathan Weizenbaum (nex3)]: https://github.com/nex3
[rb-inotify]: https://github.com/nex3/rb-inotify
[stereobooster]: https://github.com/stereobooster
[rb-fchange]: https://github.com/stereobooster/rb-fchange
[Yehuda Katz (wycats)]: https://github.com/wycats
[vigilo]: https://github.com/wycats/vigilo
