# Issues and troubleshooting

## 3 steps before you start diagnosing problems

These 3 steps will:
* help quickly troubleshoot issues caused by obscure problems
* help quickly identify the area of the problem (a full list is [below](#known-issues))
* help you get familiar with listen's diagnostic mode
* help you create relevant output before you submit an issue

1) For effective troubleshooting set the `LISTEN_GEM_DEBUGGING=1` variable
before starting listen.

2) Verify polling works (see `force_polling` option).

After starting listen, you should see something like:
```
INFO -- : Celluloid loglevel set to: 1
INFO -- : Record.build(): 0.06773114204406738 seconds
```

(Listen uses [Celluloid](https://github.com/celluloid/celluloid) for logging, so if you don't see anything, `Celluloid.logger` might have been disabled by a different gem, e.g. sidekiq)

If you don't see the line `Record.build()`:
* and there's a lot of disk activity, you may have to wait a few seconds
* you may be using an outdated version of Listen
* listen may have got stuck on a recursive symlink, see #259

3) Make changes e.g. `touch foo` or `echo "a" >> foo` (for troubleshooting, avoid using an editor which could generate too many misleading events)

You should see something like:

```
INFO -- : listen: raw changes: [[:added, "/home/me/foo"]]
INFO -- : listen: final changes: {:modified=>[], :added=>["/home/me/foo"], :removed=>[]}
```

"raw changes" contains changes collected during the `:wait_for_delay` and `:latency` intervals, while "final changes" is what listen decided are relevant changes (for better editor support).

## Adapter-specific diagnostics

Use the `LISTEN_GEM_DEBUGGING` set to `2` for additional info.

E.g. you'll get:

```
INFO -- : Celluloid loglevel set to: 0
DEBUG -- : Broadcaster: starting tcp server: 127.0.0.1:4000
DEBUG -- : Adapter: considering TCP ...
DEBUG -- : Adapter: considering polling ...
DEBUG -- : Adapter: considering optimized backend...
INFO -- : Record.build(): 0.0007264614105224609 seconds
DEBUG -- : inotify: foo ([:create])
DEBUG -- : raw queue: [:file, #<Pathname:/tmp/x>, "foo", {:change=>:added}]
DEBUG -- : added: file:/tmp/x/foo ({:change=>:added})
DEBUG -- : inotify: foo ([:attrib])
DEBUG -- : raw queue: [:file, #<Pathname:/tmp/x>, "foo", {:change=>:modified}]
DEBUG -- : inotify: foo ([:close_write, :close])
DEBUG -- : raw queue: [:file, #<Pathname:/tmp/x>, "foo", {:change=>:modified}]
DEBUG -- : modified: file:/tmp/x/foo ({:change=>:modified})
DEBUG -- : modified: file:/tmp/x/foo ({:change=>:modified})
INFO -- : listen: raw changes: [[:added, "/tmp/x/foo"]]
INFO -- : listen: final changes: {:modified=>[], :added=>["/tmp/x/foo"], :removed=>[]}
DEBUG -- : Callback took 4.410743713378906e-05 seconds
```

This shows:
* host port listened to (for forwarding events)
* the actual adapter used (here, it's "optimized backend")
* the event received (here it's `:create` from rb-inotify)
* "raw queue" - events queued for processing (collected during `:latency`)
* "Callback took" - how long it took your app to process changes

#### Known issues

Here are common issues grouped by area in which they occur:

1. System/OS
  * [Update your Dropbox client](http://www.dropbox.com/downloading), if you have Dropbox installed.
  * old MacOS (< 10.6)
  * certain old versions of Ruby (try a newer Ruby on Windows for `wdm` and TCP mode to work)
  * system limits
    * threads for Celluloid (e.g. Virtual Machine CPU/RAM limitations)
    * [inotify limits (Linux)](https://github.com/guard/listen/wiki/Increasing-the-amount-of-inotify-watchers)
  * system in an inconsistent state or stuck (try rebooting/updating on Windows/Mac - seriously!)
  * FSEvent bug: (http://feedback.livereload.com/knowledgebase/articles/86239)

2. Installation/gems/config
  * not running listen or your app (e.g. guard) with `bundle exec` first
  * old version of listen
  * problems with adapter gems (`wdm`, `rb-fsevent`, `rb-inotify`) not installed, not detected properly (Windows) or not in Gemfile (Windows)
  * Celluloid actors are silently crashing (when no LISTEN_GEM_DEBUGGING variable is present)
  * see the [Performance](https://github.com/guard/listen/blob/master/README.md#Performance) section in the README

3. Filesystem
  * VM shared folders and network folders (NFS, Samba, SSHFS) don't work with optimized backends (workaround: polling, [TCP mode](https://github.com/guard/listen/blob/master/README.md#forwarding-file-events-over-tcp), Vagrant's rsync-auto mode, rsync/unison)
  * FAT/HFS timestamps have 1-second precision, which can cause polling and rb-fsevent to be very slow on large files (try `LISTEN_GEM_DISABLE_HASHING` variable)
  * virtual filesystems may not implement event monitoring
  * restrictive file/folder permissions
  * watched folders moved/removed while listen was running (try restarting listen and moving/copying watched folder to a new location)

4. Insufficient latency (for polling and rb-fsevent)
  * too many files being watched (polling) and not enough threads or CPU power
  * slow editor save (see below)
  * slow hard drive
  * encryption
  * a combination of factors

5. Too few or too many callbacks (`:wait_for_delay` option)
  * complex editor file-save causes events to happen during callback (result: multiple callbacks if wait_for_delay is too small)
  * too large when using TCP mode (see timestamps in output to debug)
  * too many changes happening too frequently (use ignore rules to filter them out)

6. Paths
  * default ignore rules
  * encoding-related issues (bad filenames, mounted FS encoding mismatch)
  * symlinks may cause listen to hang (#259)
  * symlinks may not work as you expect or work differently for polling vs non-polling
  * TCP paths don't match with client's current working directory

7. Editors
  * "atomic save" in editors may confuse listen (disable it and try again)
  * listen's default ignore rules may need tweaking
  * your editor may not be supported yet (see default ignore rules for editors)
  * use `touch foo` or `echo "a" >> foo`  to confirm it's an editor issue
  * slow terminal/GFX card, slow font, transparency effects in terminal
  * complex/lengthy editor save (due to e.g. many plugins running during save)
  * listen has complex rules for detecting atomic file saves (Linux)

8. TCP (tcp mode) issues
  * not a recent listen gem (before 2.7.11)
  * additional network delay and collecting may need a higher `:wait_for_delay` value
  * changes (added, removed, deleted) not matching actual changes

If your application keeps using the polling-adapter and you can't figure out why, feel free to [open an issue](https://github.com/guard/listen/issues/new) (and be sure to [give all the details](https://github.com/guard/listen/blob/master/CONTRIBUTING.md)).

Listen traps SIGINT signal to properly finalize listeners. If you plan
on trapping this signal yourself - make sure to call `Listen.stop` in
signal handler.
