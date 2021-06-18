# Lapis
A DataStore abstraction library for Roblox that offers:
- Session locking
- Validators
- Migrations
- ~Compression~
- Retries
- Throttling
- ~Autosaving~
- Promise based API

This library was inspired by [Quicksave](https://github.com/evaera/Quicksave).

## Warning
This library is not meant for production yet. There may be some breaking changes before the initial release.
Autosaving isn't yet implemented so session locking will not work as intended unless you implement your own autosaving.
The library is setup to support compression but I don't know much about compression. The method that Quicksave used didn't work with all UTF-8 encoded characters.

## To do
- Autosaving
- Compresion
