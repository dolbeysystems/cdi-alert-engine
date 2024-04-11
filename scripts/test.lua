---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Test Alert
---
--- This is a test alert script that always passes with several links 
---
--- Date: 4/10/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Link Creation
--------------------------------------------------------------------------------
--- Top-level link for holding documentation links
---
--- @type CdiAlertLink
local codeHeading = CdiAlertLink:new()
codeHeading.link_text = "Code Links"

--- Top-level links for holding clinical evidence
---
--- @type CdiAlertLink
local documentHeading = CdiAlertLink:new()
documentHeading.link_text = "Document Links"

-- @type CdiAlertLink[]
local codeLinks = {}

local htLink = MakeCodeLink(codeLinks, "I10", "Hypertension", 1)
local diabetesLink = MakeCodeLink(codeLinks, "E11", "Diabetes", 2)

-- @type CdiAlertLink[]
local documentLinks = {}

local dischargeSummaryLink = MakeDocumentLink(documentLinks, "Discharge Summary", "Discharge Summary Document", 1)
local physicianNoteLink = MakeDocumentLink(documentLinks, "Physician Note", "Physician Note Document", 2)

codeHeading.links = codeLinks
documentHeading.links = documentLinks

--- @type CdiAlertLink[]
local resultLinks = {}

if codeHeading.links then
    table.insert(resultLinks, codeHeading)
else
    warn("No links under code heading")
end
if documentHeading.links then
    table.insert(resultLinks, documentHeading)
else
    warn("No links under document heading")
end

if not htLink then
   warn("htLink was not found")
end
if not diabetesLink then
   warn("diabetesLink was not found")
end
if not dischargeSummaryLink then
   warn("dischargeSummaryLink was not found")
end
if not physicianNoteLink then
   warn("physicianNoteLink was not found")
end



--------------------------------------------------------------------------------
--- Result Finalization
--------------------------------------------------------------------------------
result.links = resultLinks
result.passed = true
result.outcome = "Test outcome"

