# !!! CHANGELOG moved to Github [releases](https://github.com/guard/listen/releases) page !!!


## 1.2.2 - Jun 17, 2013

### Bug fix

- Rescue all error on sha1_checksum generation. ([@thibaudgg][])

## 1.2.1 - Jun 11, 2013

### Improvement

- Ignore 'bundle' folder by default. ([@thibaudgg][])

## 1.2.0 - Jun 11, 2013

### Improvement

- [#124][] New `force_adapter` option, skip the `.listen_test` adapter test. ([@nicobrevin][])

## 1.1.6 - Jun 4, 2013

### Change

- [#120][] Warn when using relative_paths option when listening to multiple diretories. (reported by [@chriseppstein][], added by [@thibaudgg][])

## 1.1.5 - Jun 3, 2013

### Bug fix

- [#122][] Fix stop called very soon after starting. (reported by [@chriseppstein][], fixed by [@thibaudgg][])

## 1.1.4 - May 28, 2013

### Bug fix

- [#118][] Prevent polling just because the adapter gem was already required. ([@nilbus][])

## 1.1.3 - May 21, 2013

### Bug fix

- [#117][] Fix jruby error on Pathname#relative_path_from. ([@luikore][])

## 1.1.2 - May 14, 2013

### Bug fix

- [#115][] Fix for directory containing non-ascii chars. ([@luikore][])

## 1.1.1 - May 14, 2013

### Bug fix

- [#113][] Kill poller_thread before waiting for it to die. ([@antifuchs][])

## 1.1.0 - May 11, 2013

### Bug fix

- [#112][] Expand path for the given directories. (reported by [@nex3][], fixed by [@thibaudgg][])

### Change

- [#110][] Remove MultiListener deprecation warning message. (reported by [@nex3][], fixed by [@thibaudgg][])

## 1.0.3 - April 29, 2013

### Bug fix

- Rescue Errno::EBADF on sha1_checksum generation. ([@thibaudgg][])

## 1.0.2 - April 22, 2013

### Bug fix

- [#104][] Avoid conflict with ActiveSupport::Dependencies::Loadable. ([@nysalor][])

## 1.0.1 - April 22, 2013

### Bug fix

- [#103][] Support old version of rubygems. (reported by [@ahoward][], fixed by [@thibaudgg][])

## 1.0.0 - April 20, 2013

### Bug fix

- [#93][] Remove dependency operator in the "gem install" message. (reported by [@scottdavis][], fixed by [@rymai][])

### Changes & deprecations

- [#98][] `Listen.to` does not block the current thread anymore. Use `Listen.to!` if you want the old behavior back. ([@rymai][])
- [#98][] `Listen::Listener#start` does not block the current thread anymore. Use `Listen::Listener#start!` if you want the old behavior back. ([@rymai][])
- [#98][] `Listen::Listener#start`'s `blocking` parameter is deprecated. ([@rymai][])

### Improvements

- [#98][] New method: `Listen.to!` which blocks the current thread. ([@rymai][])
- [#98][] New method: `Listen::Listener#start!` to start the listener and block the current thread. ([@martikaljuve][] & [@rymai][])
- [#95][] Make `Listen::Listener` capable of listening to multiple directories, deprecates `Listen::MultiListener`, defaults `Listener#relative_paths` to `true` when listening to a single directory (see [#131][]). ([@rymai][])
- [#85][] Compute the SHA1 sum only for regular files. ([@antifuchs][])
- New methods: `Listen::Adapter#pause`, `Listen::Adapter#unpause` and `Listen::Adapter#paused?`. ([@rymai][])
- Refactor `Listen::DirectoryRecord` internals. ([@rymai][])
- Refactor `Listen::DependencyManager` internals. ([@rymai][])

## 0.7.3 - February 24, 2013

### Bug fixes

- [#88][] Update wdm dependency. ([@mrbinky3000][])
- [#78][] Depend on latest rb-inotify. ([@mbj][])

## 0.7.2 - January 11, 2013

### Bug fix

- [#76][] Exception on filename which is not in UTF-8. ([@piotr-sokolowski][])

## 0.7.1 - January 6, 2013

### Bug fix

- [#75][] Default high precision off if the mtime call fails. ([@zanker][])

## 0.7.0 - December 29, 2012

### Bug fix

- [#73][] Rescue Errno::EOPNOTSUPP on sha1_checksum generation. ([@thibaudgg][])

### New feature

- [#72][] Add support for *BSD with rb-kqueue. ([@mat813][])

## 0.6.0 - November 21, 2012

### New feature

- [#68][] Add bang versions for `Listener#filter` and `Listener#ignore` methods. ([@tarsolya][])

## 0.5.3 - October 3, 2012

### Bug fixes

- [#65][] Fix ruby warning in adapter.rb. ([@vongruenigen][])
- [#64][] ENXIO raised when hashing UNIX domain socket file. ([@sunaku][])

## 0.5.2 - Septemper 23, 2012

### Bug fix

- [#62][] Fix double change callback with polling adapter. ([@thibaudgg][])

## 0.5.1 - Septemper 18, 2012

### Bug fix

- [#61][] Fix a synchronisation bug that caused constant fallback to polling. ([@Maher4Ever][])

## 0.5.0 - Septemper 1, 2012

### New features

- Add a dependency manager to handle platform-specific gems. So there is no need anymore to install
  extra gems which will never be used on the user system. ([@Maher4Ever][])
- Add a manual reporting mode to the adapters. ([@Maher4Ever][])

### Improvements

- [#28][] Enhance the speed of detecting changes on Windows by using the [WDM][] library. ([@Maher4Ever][])

## 0.4.7 - June 27, 2012

### Bug fixes

- Increase latency to 0.25, to avoid useless polling fallback. ([@thibaudgg][])
- Change watched inotify events, to avoid duplication callback. ([@thibaudgg][])
- [#41][] Use lstat instead of stat when calculating mtime. ([@ebroder][])

## 0.4.6 - June 20, 2012

### Bug fix

- [#39][] Fix digest race condition. ([@dkubb][])

## 0.4.5 - June 13, 2012

### Bug fix

- [#39][] Rescue Errno::ENOENT when path inserted doesn't exist. (reported by [@textgoeshere][], fixed by [@thibaudgg][] and [@rymai][])

## 0.4.4 - June 8, 2012

### Bug fixes

- ~~[#39][] Non-existing path insertion bug. (reported by [@textgoeshere][], fixed by [@thibaudgg][])~~
- Fix relative path for directories containing special characters. (reported by [@napcs][], fixed by [@netzpirat][])

## 0.4.3 - June 6, 2012

### Bug fixes

- [#24][] Fail gracefully when the inotify limit is not enough for Listen to function. (reported by [@daemonza][], fixed by [@Maher4Ever][])
- [#32][] Fix a crash when trying to calculate the checksum of unreadable files. (reported by [@nex3][], fixed by [@Maher4Ever][])

### Improvements

- Add `Listener#relative_paths`. ([@Maher4Ever][])
- Add `Adapter#started?`. ([@Maher4Ever][])
- Dynamically detect the mtime precision used on a system. ([@Maher4Ever][] with help from [@nex3][])

## 0.4.2 - May 1, 2012

### Bug fixes

- [#21][] Issues when listening to changes in relative paths. (reported by [@akerbos][], fixed by [@Maher4Ever][])
- [#27][] Wrong reports for files modifications. (reported by [@cobychapple][], fixed by [@Maher4Ever][])
- Fix segmentation fault when profiling on Windows. ([@Maher4Ever][])
- Fix redundant watchers on Windows. ([@Maher4Ever][])

### Improvements

- [#17][] Use regexp-patterns with the `ignore` method instead of supplying paths. (reported by [@fny][], added by [@Maher4Ever][])
- Speed improvement when listening to changes in directories with ignored paths. ([@Maher4Ever][])
- Added `.rbx` and `.svn` to ignored directories. ([@Maher4Ever][])

## 0.4.1 - April 15, 2012

### Bug fix

- [#18][] Listener crashes when removing directories with nested paths. (reported by [@daemonza][], fixed by [@Maher4Ever][])

## 0.4.0 - April 9, 2012

### New features

- Add `Adapter#wait_for_callback`. ([@Maher4Ever][])
- Add `Listen::MultiListener` class to listen to multiple directories at once. ([@Maher4Ever][])
- Allow passing multiple directories to the `Listen.to` method. ([@Maher4Ever][])
- Add `blocking` option to `Listen#start` which can be used to disable blocking the current thread upon starting. ([@Maher4Ever][])
- Use absolute-paths in callbacks by default instead of relative-paths. ([@Maher4Ever][])
- Add `relative_paths` option to `Listen::Listener` to retain the old functionality. ([@Maher4Ever][])

### Improvements

- Encapsulate thread spawning in the linux-adapter. ([@Maher4Ever][])
- Encapsulate thread spawning in the darwin-adapter. ([@Maher4Ever][] with [@scottdavis][] help)
- Encapsulate thread spawning in the windows-adapter. ([@Maher4Ever][])
- Fix linux-adapter bug where Listen would report file-modification events on the parent-directory. ([@Maher4Ever][])

### Change

- Remove `wait_until_listening` as adapters doesn't need to run inside threads anymore ([@Maher4Ever][])

## 0.3.3 - March 6, 2012

### Improvement

- Improve pause/unpause. ([@thibaudgg][])

## 0.3.2 - March 4, 2012

### New feature

- Add pause/unpause listener's methods. ([@thibaudgg][])

## 0.3.1 - February 22, 2012

### Bug fix

- [#9][] Ignore doesn't seem to work. (reported by [@markiz][], fixed by [@thibaudgg][])

## 0.3.0 - February 21, 2012

### New features

- Add automatic fallback to polling if system adapter doesn't work (like a DropBox folder). ([@thibaudgg][])
- Add latency and force_polling options. ([@Maher4Ever][])

## 0.2.0 - February 13, 2012

### New features

- Add checksum comparaison support for detecting consecutive file modifications made during the same second. ([@thibaudgg][])
- Add rb-fchange support. ([@thibaudgg][])
- Add rb-inotify support. ([@thibaudgg][] with [@Maher4Ever][] help)
- Add rb-fsevent support. ([@thibaudgg][])
- Add non-recursive diff with multiple directories support. ([@thibaudgg][])
- Ignore `.DS_Store` files by default. ([@thibaudgg][])

## 0.1.0 - January 28, 2012

- First version with only a polling adapter and basic features set (ignore & filter). ([@thibaudgg][])

<!--- The following link definition list is generated by PimpMyChangelog --->
[#9]: https://github.com/guard/listen/issues/9
[#17]: https://github.com/guard/listen/issues/17
[#18]: https://github.com/guard/listen/issues/18
[#21]: https://github.com/guard/listen/issues/21
[#24]: https://github.com/guard/listen/issues/24
[#27]: https://github.com/guard/listen/issues/27
[#28]: https://github.com/guard/listen/issues/28
[#32]: https://github.com/guard/listen/issues/32
[#39]: https://github.com/guard/listen/issues/39
[#41]: https://github.com/guard/listen/issues/41
[#61]: https://github.com/guard/listen/issues/61
[#62]: https://github.com/guard/listen/issues/62
[#64]: https://github.com/guard/listen/issues/64
[#65]: https://github.com/guard/listen/issues/65
[#68]: https://github.com/guard/listen/issues/68
[#72]: https://github.com/guard/listen/issues/72
[#73]: https://github.com/guard/listen/issues/73
[#75]: https://github.com/guard/listen/issues/75
[#76]: https://github.com/guard/listen/issues/76
[#78]: https://github.com/guard/listen/issues/78
[#85]: https://github.com/guard/listen/issues/85
[#88]: https://github.com/guard/listen/issues/88
[#93]: https://github.com/guard/listen/issues/93
[#95]: https://github.com/guard/listen/issues/95
[#96]: https://github.com/guard/listen/issues/96
[#98]: https://github.com/guard/listen/issues/98
[#103]: https://github.com/guard/listen/issues/103
[#104]: https://github.com/guard/listen/issues/104
[#110]: https://github.com/guard/listen/issues/110
[#112]: https://github.com/guard/listen/issues/112
[#113]: https://github.com/guard/listen/issues/113
[#115]: https://github.com/guard/listen/issues/115
[#117]: https://github.com/guard/listen/issues/117
[#118]: https://github.com/guard/listen/issues/118
[#120]: https://github.com/guard/listen/issues/120
[#122]: https://github.com/guard/listen/issues/122
[#124]: https://github.com/guard/listen/issues/124
[#131]: https://github.com/guard/listen/issues/131
[@21croissants]: https://github.com/21croissants
[@Maher4Ever]: https://github.com/Maher4Ever
[@ahoward]: https://github.com/ahoward
[@akerbos]: https://github.com/akerbos
[@antifuchs]: https://github.com/antifuchs
[@chriseppstein]: https://github.com/chriseppstein
[@cobychapple]: https://github.com/cobychapple
[@daemonza]: https://github.com/daemonza
[@dkubb]: https://github.com/dkubb
[@ebroder]: https://github.com/ebroder
[@fny]: https://github.com/fny
[@luikore]: https://github.com/luikore
[@markiz]: https://github.com/markiz
[@martikaljuve]: https://github.com/martikaljuve
[@mat813]: https://github.com/mat813
[@mbj]: https://github.com/mbj
[@mrbinky3000]: https://github.com/mrbinky3000
[@napcs]: https://github.com/napcs
[@netzpirat]: https://github.com/netzpirat
[@nex3]: https://github.com/nex3
[@nicobrevin]: https://github.com/nicobrevin
[@nilbus]: https://github.com/nilbus
[@nysalor]: https://github.com/nysalor
[@piotr-sokolowski]: https://github.com/piotr-sokolowski
[@rehevkor5]: https://github.com/rehevkor5
[@rymai]: https://github.com/rymai
[@scottdavis]: https://github.com/scottdavis
[@sunaku]: https://github.com/sunaku
[@tarsolya]: https://github.com/tarsolya
[@textgoeshere]: https://github.com/textgoeshere
[@thibaudgg]: https://github.com/thibaudgg
[@vongruenigen]: https://github.com/vongruenigen
[@zanker]: https://github.com/zanker
