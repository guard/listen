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
