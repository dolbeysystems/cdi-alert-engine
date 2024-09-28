# CDI Alert Engine

Processes CDI alerts from the CdiAlertQueue collection in the FusionCAC2 database by running various
CDI scripts that collect evidence, and the assigning the workgroup/criteria group based on the results
of those CDI scripts.

See [Motivations](./doc/cdi-alert-engine-motivations.md) for initial motivations for this project, pending
additional documentation.

# Configuration

The CDI alert engine is configured using Lua scripts,
rather than a more conventional declaritive format like TOML or JSON.
However, the syntax of Lua should be relatively familiar if you've used either of these formats before.

As an example:

```lua
polling_seconds = 5
script_engine_workflow_rest_url = "http://dockermain:5195/api/ProcessWorkflow/"

mongo = {
	url = "mongodb://dolbeyadmin:fusion@dockermain:27095/admin",
	database = "FusionCAC2",
}

-- Define a base set of scripts.
-- Other config files are expected to execute this one and then modify the script table.
scripts = {
	["scripts/substance_abuse.lua"] = {
		criteria_group = "Substance Abuse",
	},
  -- etc ...
}
```

As a scripting language, Lua has some advantages over a "static" configuration file format.
For example, using the `dofile` function, Lua can import and modify the values of a "base" config file:

base.lua:
```lua
polling_seconds = 5
create_test_accounts = 10

scripts = {
  ["scripts/substance_abuse.lua"] = {
		criteria_group = "Substance Abuse",
	},
  ["scripts/test.lua"] = {
		criteria_group = "Test Group",
	}
}
```

derivative.lua:
```lua
dofile("base.lua")

-- Change the number of test accounts from the base script.
create_test_accounts = 0

-- Delete the entry for the test script.
scripts["scripts/test.lua"] = nil
```
