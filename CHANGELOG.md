## 0.4.1 - April 15, 2012

### Bug fixes

- [#18](https://github.com/guard/listen/issues/18): Listener crashes when removing directories with nested paths (reported by [@daemonza][], fixed by [@Maher4Ever][])

## 0.4.0 - April 9, 2012

### New features

- Add `wait_for_callback` method to all adapters. ([@Maher4Ever][])
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

### Removals

- Remove `wait_until_listening` as adapters doesn't need to run inside threads anymore ([@Maher4Ever][])

## 0.3.3 - March 6, 2012

### Improvements

- Improve pause/unpause. ([@thibaudgg][])

## 0.3.2 - March 4, 2012

### New features

- Add pause/unpause listener's methods. ([@thibaudgg][])

## 0.3.1 - February 22, 2012

### Bug fix

- [#9](https://github.com/guard/listen/issues/9): Ignore doesn't seem to work. (reported by [@markiz][], fixed by [@thibaudgg][])

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
- Ignore .DS_Store by default. ([@thibaudgg][])

## 0.1.0 - January 28, 2012

- First version with only a polling adapter and basic features set (ignore & filter). ([@thibaudgg][])

[@markiz]: https://github.com/markiz
[@thibaudgg]: https://github.com/thibaudgg
[@Maher4Ever]: https://github.com/Maher4Ever
[@daemonza]: https://github.com/daemonza
