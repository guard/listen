# Listen [![Build Status](https://secure.travis-ci.org/guard/listen.png?branch=master)](http://travis-ci.org/guard/listen)

**Work in progress...**

The Listen gem listens to file modifications and notifies you about the changes.

## TODO

- **DONE** Add polling support
- **DONE** Add `rb-fsevent` support
- **DONE** Add `rb-inotify` support
- **DONE** Add `rb-fchange` support
- **DONE** Add checksum comparaison support for detecting consecutive file modifications made during the same second. (like Guard)
- Add latency option
- Add polling option (true: polling forced, false: polling never used (to skip DropBox polling fallback))
- Dropbox detection with polling fallback (if needed)
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
listener = listener.change(&callback)
listener.start # enter the run loop
listener.stop
```

#### Chainable

``` ruby
Listen.to('dir/path/to/listen').ignore('/ignored/path').filter(/.*\.rb/).change(&callback).start # enter the run loop
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
:filter => /.*\.rb/, /.*\.coffee/   # Filter files to listen to via a regexps list.
                                    # default: none

:ignore => 'path1', 'path2'         # Ignore a list of paths (root directory or sub-dir)
                                    # default: '.bundle', '.git', 'log', 'tmp', 'vendor'
```