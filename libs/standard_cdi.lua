---------------------------------------------------------------------------------------------
--- standard_cdi.lua - A library of common functions for use in cdi alert scripts
---------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------
--- Requires
---------------------------------------------------------------------------------------------
require("libs.common")



---------------------------------------------------------------------------------------------
--- Globals
---------------------------------------------------------------------------------------------
ExistingAlert = GetExistingCdiAlert{ scriptName = ScriptName }
AlertMatched = false
AlertAutoResolved = false

DocumentationIncludesHeader = MakeHeaderLink("Documentation Includes")
ClinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
TreatmentHeader = MakeHeaderLink("Treatment")
VitalsHeading = MakeHeaderLink("Vital Signs/Intake and Output Data")

--- @type CdiAlertLink[]
DocumentationIncludesLinks = {}

--- @type CdiAlertLink[]
ClinicalEvidenceLinks = {}

--- @type CdiAlertLink[]
TreatmentLinks = {}

--- @type CdiAlertLink[]
VitalsLinks = {}



---------------------------------------------------------------------------------------------
--- Functions
---------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Clinical Evidence Header Temp Links
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddEvidenceAbs(code, text, seq)
    GetAbstractionLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a code link to the Clinical Evidence Header Temp Links
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddEvidenceCode(code, text, seq)
    GetCodeLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a medication link to the Treatment Header Temp Links
---
--- @param cat string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentMed(cat, text, seq)
    GetMedicationLinks { target=TreatmentLinks, cat=cat, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Treatment Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentAbs(code, text, seq)
    GetAbstractionValueLinks { target=TreatmentLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a code link to the Treatment Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentCode(code, text, seq)
    GetCodeLinks { target=TreatmentLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Vitals Header Temp Links
---
--- @param dv string[]
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddVitalsDv(dv, text, seq)
    GetDiscreteValueLinks { target=VitalsLinks, discreteValueNames=dv, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Vitals Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddVitalsAbs(code, text, seq)
    GetAbstractionValueLinks { target=VitalsLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Get the final top links for the CDI alert
---
--- @param additionalHeaders CdiAlertLink[] Additional headers to add to the final top links
---
--- @return CdiAlertLink[] - The final top links for the CDI alert
--------------------------------------------------------------------------------
function GetFinalTopLinks(additionalHeaders)
    local finalLinks = {}

    if #DocumentationIncludesLinks > 0 then
        DocumentationIncludesHeader.links = DocumentationIncludesLinks
        table.insert(finalLinks, DocumentationIncludesHeader)
    end
    if #ClinicalEvidenceLinks > 0 then
        ClinicalEvidenceHeader.links = ClinicalEvidenceLinks
        table.insert(finalLinks, ClinicalEvidenceHeader)
    end
    if #VitalsLinks > 0 then
        VitalsHeading.links = VitalsLinks
        table.insert(finalLinks, VitalsHeading)
    end
    if #TreatmentLinks > 0 then
        TreatmentHeader.links = TreatmentLinks
        table.insert(finalLinks, TreatmentHeader)
    end

    for _, header in ipairs(additionalHeaders) do
        table.insert(finalLinks, header)
    end
    return finalLinks
end
