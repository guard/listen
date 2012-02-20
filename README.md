# Listen [![Build Status](https://secure.travis-ci.org/guard/listen.png?branch=master)](http://travis-ci.org/guard/listen)

**Work in progress...**

The Listen gem listens to file modifications and notifies you about the changes.

## TODO

- **DONE** Add polling support
- **DONE** Add `rb-fsevent` support
- **DONE** Add `rb-inotify` support
- **DONE** Add `rb-fchange` support
- **DONE** Add checksum comparaison support for detecting consecutive file modifications made during the same second. (like Guard)
- **DONE** Add latency option
- **DONE** Add force-polling option
- **DONE** Add automatic fallback to polling if system adapter doesn't work (like a DropBox folder).
- Improve API (if needed)

## Install

``` bash
gem install listen
```

## Usage

There are two ways you can use Listen.

1. call `Listen.to` with a path params, and define callbacks in a block.
3. create a `listener` object usable in an (ARel style) chainable way.

Feel free to give your feeback via [Listen issues](https://github.com/guard/listener/issues)

### Block API

#### One dir

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

### Listen adapters

The Listen gem has a set of adapters to notify it when there are changes.
There are 3 OS-specific adapters to support Mac, Linux and Windows. These adapters are fast
as they use some system-calls to implement the notifying function.

There is also a polling adapter which is a cross-platform adapter and it will
work on any system. This adapter is unfortunately slower than the rest of the adapters.

The Listen gem will choose the best and working adapter for your machine automatically. If you
want to force the use of the polling adapter, either use the `:force_polling` option
while initializing the listener or call the `force_polling` method on your listener
before starting it.

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

## Acknowledgment

- [Travis Tilley (ttilley)][] for this awesome work on [fssm][] & [rb-fsevent][].
- [Nathan Weizenbaum (nex3)][] for [rb-inotify][], a thorough inotify wrapper.
- [stereobooster][] for [rb-fchange][], windows support wouldn't exist without him.
- [Yehuda Katz (wycats)][] for [vigilo][], that has been a great source of inspiration.

[Travis Tilley (ttilley)]: https://github.com/ttilley
[fssm]: https://github.com/ttilley/fssm
[rb-fsevent]: https://github.com/thibaudgg/rb-fsevent
[Nathan Weizenbaum (nex3)]: https://github.com/nex3
[rb-inotify]: https://github.com/nex3/rb-inotify
[stereobooster]: https://github.com/stereobooster
[rb-fchange]: https://github.com/stereobooster/rb-fchange
[Yehuda Katz (wycats)]: https://github.com/wycats
[vigilo]: https://github.com/wycats/vigilo
