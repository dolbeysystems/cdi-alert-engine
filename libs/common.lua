---------------------------------------------------------------------------------------------
--- common.lua - A library of common functions for use in all alert scripts
---------------------------------------------------------------------------------------------
require("libs.common.dates")
require("libs.common.codes")
require("libs.common.documents")
require("libs.common.medications")
require("libs.common.discrete_values")
require("libs.common.basic_links")
require("libs.common.alerts")
require("libs.common.blood")

--------------------------------------------------------------------------------
--- Global setup/configuration
--------------------------------------------------------------------------------
-- This is here because of unpack having different availability based on lua version
-- (Basically, to make LSP integration happy)
if not table.unpack then
    --- @diagnostic disable-next-line: deprecated
    table.unpack = unpack
end
