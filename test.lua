local function not_passed(result)
    return not result.passed,
        "Expected result not to pass, but it did."
end

local function autoresolve(result)
    return result.passed and result.outcome == "AUTORESOLVED",
        "Expected autoresolve result, got result { passed = " ..
        tostring(result.passed) .. ", outcome = " .. result.outcome .. " }"
end

return {
    ["scripts/nicotine_dependence_with_withdrawal.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/nicotine_dependence_with_withdrawal/present.lua"] = function(result)
            return result.passed and result.outcome == nil
        end,
        ["test/nicotine_dependence_with_withdrawal/autoresolve.lua"] = autoresolve,
    },
    ["scripts/atrial_fibrillation.lua"] = {
        ["test/identity.lua"] = not_passed,
        ["test/atrial_fibrillation/unspecified.lua"] = function(result)
            return result.passed and result.subtitle == "Unspecified Atrial Fibrillation Dx"
        end,
        ["test/atrial_fibrillation/conflicting.lua"] = function(result)
            return result.passed and result.subtitle == "Conflicting Atrial Fibrillation Dx"
        end,
        ["test/atrial_fibrillation/autoresolve.lua"] = autoresolve,
        ["test/atrial_fibrillation/previous_autoresolve.lua"] = function(result)
            return result.passed and result.subtitle == "Conflicting Atrial Fibrillation Dx" and
                result.validated == false and result.reason == "Previously Autoresolved",
                "This test cannot pass because its conditions cause the script not to run"
        end,
    },
}
