# CDI Alert Engine Unit Tests

## Command Line Interface

Unit testing may be run using `cargo run`.

By default, `test.lua` will be used as the [test file](#test-file).
This may be overridden using `--config`.

The unit test binary accepts a list of arguments which will be used to filter the tests that are run.

For example:
- `cargo run -- script/example.lua` only tests `script/example.lua`
- `cargo run -- script/example.lua script/other.lua` only tests `script/example.lua` and `script/other.lua`.
- `cargo run -- script/example.lua:test/identity.lua` only tests account `test/identity.lua` of script `script/example.lua`.
- `cargo run -- '!script/example.lua:test/identity.lua'` runs everything except for account `test/identity.lua` of script `script/example.lua`.
- `cargo run -- script/example.lua '!script/example.lua:test/identity.lua'` only tests `script/example.lua`, except for account `test/identity.lua` of script `script/example.lua`.

`--quiet` may be used to only output failures and the summary.

## Test File

The test file describes which scripts to test,
which accounts to use as inputs,
and the expected outputs for each account.

For example:
```lua
return {
    -- Top-level table maps scripts to accounts.
    ["script/example.lua"] = {
        -- Inner table maps inputs to outputs.
        ["test/identity.lua"] = function(result)
            -- This function recieves the produced "result" object,
            -- and must return true if the result "passes".
            return not result.passed
        end,
    },
}
```

Tests will be executed in alphabetical order, NOT the order provided by this sequence.
