local function not_passed(result)
    return not result.passed,
        "Expected result not to pass, but it did."
end

local function autoresolve(result)
    return result.passed and result.outcome == "AUTORESOLVED",
        not result.passed and "Expected result to pass, but it didn't" or
        "Expected outcome \"AUTORESOLVED\", got \"" .. tostring(result.outcome) .. "\""
end

--- Check for the presence of a subtitle on a passing result.
--- Provides a failure message displaying the result's subtitle.
local function subtitle(subtitle)
    return function(result)
        return result.passed and result.subtitle == subtitle,
            not result.passed and "Expected result to pass, but it didn't" or
            "Expected subtitle \"" .. subtitle .. "\", got \"" .. tostring(result.subtitle) .. "\""
    end
end

--- Stores the last argument passed to `script`.
local current_script

local function script(name)
    current_script = name
    return "scripts/" .. name .. ".lua"
end

local function test(name)
    return "test/" .. current_script .. "/" .. name .. ".lua"
end

return {
    [script "nicotine_dependence_with_withdrawal"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "present"] = function(result)
            return result.passed and result.outcome == nil
        end,
    },
    [script "atrial_fibrillation"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "unspecified"] = subtitle "Unspecified Atrial Fibrillation Dx",
        [test "conflicting"] = subtitle "Conflicting Atrial Fibrillation Dx",
        [test "previous_autoresolve"] = function(result)
            return result.passed and result.subtitle == "Conflicting Atrial Fibrillation Dx" and
                result.validated == false and result.reason == "Previously Autoresolved"
        end,
    },
    [script "substance_abuse"] = {
        ["test/identity.lua"] = not_passed,
        [test "alcohol_autoresolve"] = autoresolve,
        [test "opioid_autoresolve"] = autoresolve,
        [test "ciwa_dv"] = subtitle "Possible Alcohol Withdrawal",
        [test "methadone"] = subtitle "Possible Opioid Dependence",
    },
    [script "bleeding"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "anticoagulant"] = subtitle "Bleeding with possible link to Anticoagulant",
    },
    [script "urinary_tract_infection"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "uti_possible_cystostomy_catheter"] = subtitle "UTI Dx Possible Link To Cystostomy Catheter",
        [test "uti_possible_indwelling_catheter"] = subtitle "UTI Dx Possible Link To Indwelling Urethral Catheter",
        [test "uti_possible_nephrostomy_catheter"] = subtitle "UTI Dx Possible Link To Nephrostomy Catheter",
        [test "uti_possible_other_urinary_drainage"] = subtitle "UTI Dx Possible Link To Other Urinary Drainage Device",
        [test "uti_possible_ureteral_stent"] = subtitle "UTI Dx Possible Link To Ureteral Stent",
        [test "uti_possible_intermittent_catheterization"] = subtitle "UTI Dx Possible Link To Intermittent Catheterization",
    },
    [script "functional_quadriplegia"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "autoresolve_lacking_evidence"] = autoresolve,
        [test "lacking_evidence"] = subtitle "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence",
        [test "possible"] = subtitle "Possible Functional Quadriplegia Dx",
        [test "possible_conflicting"] = subtitle "Possible Conflicting Functional Quadriplegia Dx with Spinal Cord Injury Dx, Seek Clarification",
    },
    [script "abnormal_serum_potassium"] = {
        ["test/identity.lua"] = not_passed,
        [test "hyperkalemia_autoresolve"] = autoresolve,
        [test "hypokalemia_autoresolve"] = autoresolve,
        [test "hyperkalemia_lacking_evidence_autoresolve"] = autoresolve,
        [test "hypokalemia_lacking_evidence_autoresolve"] = autoresolve,
        [test "hyperkalemia"] = subtitle "Possible Hyperkalemia Dx",
        [test "hypokalemia"] = subtitle "Possible Hypokalemia Dx",
        [test "hyperkalemia_lacking_evidence"] = subtitle "Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence",
        [test "hypokalemia_lacking_evidence"] = subtitle "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence",
    },
    [script "coagulopathy"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "possible"] = subtitle "Possible Coagulopathy Dx",
    },
    [script "rhabdomyolysis"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve_lacking_evidence"] = autoresolve,
        [test "lacking_evidence"] = subtitle "Rhabdomyolysis Dx Lacking Supporting Evidence",
        [test "conflicting"] = function(result)
            return result.passed and result.subtitle:find("^Conflicting Rhabdomyolysis Dx Codes")
        end,
        [test "conflicting_previously_autoresolved"] = function(result)
            return
                result.passed and result.subtitle:find("^Conflicting Rhabdomyolysis Dx Codes")
                and not result.validated and result.reason == "Previously Autoresolved"
        end,
        [test "possible"] = subtitle "Possible Rhabdomyolysis Dx",
        [test "autoresolve_possible"] = autoresolve,
    },
    [script "immunocompromised"] = {
        ["test/identity.lua"] = not_passed,
        [test "autoresolve"] = autoresolve,
        [test "chronic_medication"] = subtitle "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition and Medication",
        [test "chronic"] = subtitle "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition",
        [test "medication"] = subtitle "Infection Present with Possible Link to Immunocompromised State Due to Medication",
        [test "possible"] = subtitle "Possible Immunocompromised State",
    }
}
