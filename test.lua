return {
    ["scripts/nicotine_dependence_with_withdrawal.lua"] = {
        ["test/identity.lua"] = function(result)
            return not result.passed
        end
    }
}
