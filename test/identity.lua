-- This test account is the bare minimum required to run a test.

local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
	_id = "0123456789"
}
