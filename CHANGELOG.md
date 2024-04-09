# Lapis Changelog

## Unreleased Changes
* Fix infinite iyeld in `game:BindToClose` when a document failed to load. ([#45])

[#45]: https://github.com/nezuo/lapis/pull/45

## 0.2.10 - March 25, 2024
* `Document:load` now infinitely yields and doesn't load the document after `game:BindToClose` is called. If a document
does load because UpdateAsync is called just before game close, it is automatically closed. ([#43])

[#43]: https://github.com/nezuo/lapis/pull/43

## 0.2.9 - January 1, 2024
* `Document:close` no longer errors when called again and instead returns the original promise. ([#35])
  * This is so it won't error when called from `PlayerRemoving` if `game:BindToClose` happens to run first.

[#35]: https://github.com/nezuo/lapis/pull/35

## 0.2.8 - December 27, 2023
* Removed internal compression code since compression is no longer planned ([#31])
* Data is no longer loaded if it doesn't pass the `validate` function. This means it won't be session locked and migrated. ([#32])

[#31]: https://github.com/nezuo/lapis/pull/31
[#32]: https://github.com/nezuo/lapis/pull/32

## 0.2.7 - November 12, 2023
* Add `Document:beforeSave` callback to make changes to a document before it saves ([#29])

[#29]: https://github.com/nezuo/lapis/pull/29

## 0.2.6 - October 24, 2023
* Added types ([#24])
* Added `document:beforeClose` callback to make final changes to a document before it closes ([#25])
  * This callback works even when the document is closed by `game:BindToClose`.
* Added APIs to set a document's `DataStoreKeyInfo:GetUserIds()` ([#26])
  * Changed `Collection:load(key: string)` to `Collection:load(key: string, defaultUserIds: {number}?)`
    * `defaultUserIds` only applies if it's the first time the document has ever been loaded.
  * Added `Document:addUserId(userId: number)`
  * Added `Document:removeUserId(userId: number)`

[#24]: https://github.com/nezuo/lapis/pull/24
[#25]: https://github.com/nezuo/lapis/pull/25
[#26]: https://github.com/nezuo/lapis/pull/26

## 0.2.5 - September 8, 2023
* Fix existing data not being frozen on load ([#20])

[#20]: https://github.com/nezuo/lapis/pull/20

## 0.2.4 - August 3, 2023
* Fix `game:BindToClose` not waiting for documents to close

## 0.2.3 - July 19, 2023
* Fix silly mistake where I don't return the collection from `createCollection`

## 0.2.2 - July 19, 2023
* Remove write cooldown throttling since write cooldowns [were removed](https://devforum.roblox.com/t/removal-of-6s-cool-down-for-data-stores/2436230) ([#11])
* Fix save merging algorithm ([#13])
* Added new throttle queue which allows load/save/close requests from different keys to be processed at the same time ([#15])

[#11]: https://github.com/nezuo/lapis/pull/11
[#13]: https://github.com/nezuo/lapis/pull/13
[#15]: https://github.com/nezuo/lapis/pull/15

## 0.2.1 - June 10, 2023
* Move TestEZ and DataStoreServiceMock to dev dependencies
* Remove unused files from published package

## 0.2.0 - May 24, 2023
* Renamed `Collection:openDocument` to `Collection:load`
* Renamed `retryAttempts` config setting to `saveAttempts`
* Renamed `acquireLockAttempts` config setting to `loadAttempts`
* Renamed `acquireLockDelay` config setting to `loadRetryDelay`
* Fixed edge case that allowed documents to load even when their migration version exceeded the server's latest migration
