---
sidebar_position: 3
---

# Writing Migrations
Migrations allow you to update the structure of your data over time. You can add new keys, remove ones you no longer need, or change the way you store something.

Here is an example of a few migrations:
```lua
local MIGRATIONS = {
    -- Migrate from version 1 to 2.
    function(old)
        return Dictionary.merge(old, {
            coins = 0, -- Add a key called coins to the data.
        })
    end,
    -- Migrate from version 2 to 3.
    function(old)
        -- We no longer need the playTime key, so we remove it.
        return Dictionary.removeKey(old, "playTime")
    end,
}

local collection = Lapis.createCollection("collection", {
    migrations = MIGRATIONS,
    validate = validate,
    defaultData = DEFAULT_DATA,
})
```