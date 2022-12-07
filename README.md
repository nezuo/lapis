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
This is not yet meant for production.

## To do
- Add tests for auto-saving and `game:BindToClose`
- Tie a document to a player to save when they leave
