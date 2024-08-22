-- execute the root config, then modify it
dofile "config.lua"

-- Replace this test entry.
-- This will replace any existing config,
-- and create it if it did not exist.
scripts["scripts/test.lua"] = {
	criteria_group = "test",
}

-- Assigning nil to a key deletes it:
-- Scripts["scripts/test.lua"] = nil
