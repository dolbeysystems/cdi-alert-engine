local function not_passed(result)
    return not result.passed,
        "Expected result not to pass, but it did."
end

local function autoresolve(result)
    return result.passed and result.outcome == "AUTORESOLVED",
        "Expected result { passed = true, outcome = \"AUTORESOLVED\" }, got result { passed = " ..
        tostring(result.passed) .. ", outcome = " .. tostring(result.outcome) .. " }"
end

--- Check for the presence of a subtitle on a passing result.
--- Provides a failure message displaying the result's subtitle.
local function subtitle(subtitle)
    return function(result)
        return result.passed and result.subtitle == subtitle,
            "Expected subtitle \"" .. subtitle .. "\", got \"" .. tostring(result.subtitle) .. "\""
    end
end

return {
    ["scripts/nicotine_dependence_with_withdrawal.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/nicotine_dependence_with_withdrawal/autoresolve.lua"] = autoresolve,
        ["test/nicotine_dependence_with_withdrawal/present.lua"] = function(result)
            return result.passed and result.outcome == nil
        end,
    },
    ["scripts/atrial_fibrillation.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/atrial_fibrillation/autoresolve.lua"] = autoresolve,
        ["test/atrial_fibrillation/unspecified.lua"] = subtitle("Unspecified Atrial Fibrillation Dx"),
        ["test/atrial_fibrillation/conflicting.lua"] = subtitle("Conflicting Atrial Fibrillation Dx"),
        ["test/atrial_fibrillation/previous_autoresolve.lua"] = function(result)
            return result.passed and result.subtitle == "Conflicting Atrial Fibrillation Dx" and
                result.validated == false and result.reason == "Previously Autoresolved",
                "This test cannot pass because its conditions cause the script not to run"
        end,
    },
    ["scripts/substance_abuse.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/substance_abuse/alcohol_autoresolve.lua"] = autoresolve,
        ["test/substance_abuse/opioid_autoresolve.lua"] = autoresolve,
        ["test/substance_abuse/ciwa_dv.lua"] = subtitle("Possible Alcohol Withdrawal"),
        ["test/substance_abuse/methadone.lua"] = subtitle("Possible Opioid Dependence"),
    },
    ["scripts/bleeding.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/bleeding/autoresolve.lua"] = autoresolve,
        ["test/bleeding/anticoagulant.lua"] = subtitle("Bleeding with possible link to Anticoagulant"),
    },
    ["scripts/urinary_tract_infection.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/urinary_tract_infection/autoresolve.lua"] = autoresolve,
        ["test/urinary_tract_infection/uti_possible_cystostomy_catheter.lua"] = subtitle(
            "UTI Dx Possible Link To Cystostomy Catheter"),
        ["test/urinary_tract_infection/uti_possible_indwelling_catheter.lua"] = subtitle(
            "UTI Dx Possible Link To Indwelling Urethral Catheter"),
        ["test/urinary_tract_infection/uti_possible_nephrostomy_catheter.lua"] = subtitle(
            "UTI Dx Possible Link To Nephrostomy Catheter"),
        ["test/urinary_tract_infection/uti_possible_other_urinary_drainage.lua"] = subtitle(
            "UTI Dx Possible Link To Other Urinary Drainage Device"),
        ["test/urinary_tract_infection/uti_possible_ureteral_stent.lua"] = subtitle(
            "UTI Dx Possible Link To Ureteral Stent"),
        ["test/urinary_tract_infection/uti_possible_intermittent_catheterization.lua"] = subtitle(
            "UTI Dx Possible Link To Intermittent Catheterization"),
    },
    ["scripts/functional_quadriplegia.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/functional_quadriplegia/autoresolve.lua"] = autoresolve,
        -- This script is missing a function so these tests are incomplete
    }
}
