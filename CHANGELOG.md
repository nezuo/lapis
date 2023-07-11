# Lapis Changelog

## Unreleased Changes
* Remove write cooldown throttling since write cooldowns [were removed](https://devforum.roblox.com/t/removal-of-6s-cool-down-for-data-stores/2436230)
* Fix save merging algorithm ([#13])

[#13]: https://github.com/nezuo/lapis/pull/13

## 0.2.1 - June 10, 2023
* Move TestEZ and DataStoreServiceMock to dev dependencies
* Remove unused files from published package

## 0.2.0 - May 24, 2023
* Renamed `Collection:openDocument` to `Collection:load`
* Renamed `retryAttempts` config setting to `saveAttempts`
* Renamed `acquireLockAttempts` config setting to `loadAttempts`
* Renamed `acquireLockDelay` config setting to `loadRetryDelay`
* Fixed edge case that allowed documents to load even when their migration version exceeded the server's latest migration
