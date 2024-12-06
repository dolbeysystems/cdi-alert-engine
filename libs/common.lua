---------------------------------------------------------------------------------------------
--- common.lua - A library of common functions for use in all alert scripts
---------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Global setup/configuration
--------------------------------------------------------------------------------
-- This is here because of unpack having different availability based on lua version
-- (Basically, to make LSP integration happy)
if not table.unpack then
    --- @diagnostic disable-next-line: deprecated
    table.unpack = unpack
end

