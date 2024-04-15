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
require("libs.standard_cdi")



--------------------------------------------------------------------------------
--- Link Creation
--------------------------------------------------------------------------------
local codeHeading = MakeHeaderLink("Code Links")
local documentHeading = MakeHeaderLink("Document Links")

local codeLinks = MakeLinkArray()
local htLink =       GetCodeLinks { target=codeLinks, code="I10", text="Hypertension", seq=1 }
local diabetesLink = GetCodeLinks { target=codeLinks, code="E11", text="Diabetes", seq=2 }

local documentLinks = MakeLinkArray()
local dischargeSummaryLink = GetDocumentLinks { target=documentLinks, documentType="Discharge Summary", text="Discharge Summary Document", seq=1 }
local physicianNoteLink =    GetDocumentLinks { target=documentLinks, documentType="Physician Note", text="Physician Note Document", seq=2 }

codeHeading.links = codeLinks
documentHeading.links = documentLinks

local resultLinks = MakeLinkArray()

if codeHeading.links then
    table.insert(resultLinks, codeHeading)
else
    warn("No links under code heading")
end
if documentHeading.links then table.insert(resultLinks, documentHeading)
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
Result.links = resultLinks
Result.passed = true
Result.outcome = "Test outcome"

info(ScriptName .. " - Test alert script completed successfully")

