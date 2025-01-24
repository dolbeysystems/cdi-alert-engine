return {
    ["scripts/nicotine_dependence_with_withdrawal.lua"] = {
        ["test/identity.lua"] = function(result)
            return not result.passed
        end,
        ["test/nicotine_dependence_with_withdrawal/present.lua"] = function(result)
            return result.passed and result.outcome == nil
        end,
        ["test/nicotine_dependence_with_withdrawal/autoclose.lua"] = function(result)
            return result.passed and result.outcome == "AUTORESOLVED"
        end,
    }
}
