# Lapis
A Roblox DataStore abstraction that offers:
- Caching
- Session locking
- Validation (rejects incorrect data)
- Migrations
- Retries
- Throttling
- Promise based API
- Immutability

This library was inspired by [Quicksave](https://github.com/evaera/Quicksave).

## Warning
This is not yet meant for production. Auto-saving is not implemented which is necessary for session locking.
Without auto-saving, a session lock can be considered expired since it's not updated often.

## To do
- Auto-saving
- Save on game close
- Tie a document to a player to save when they leave
