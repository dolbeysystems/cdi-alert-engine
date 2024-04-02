print(account.patient.first_name)
-- "1" means first... don't use 0 like I did.
print(account.documents[1].code_references[1].code)

result.passed = true
print("script passed: "..tostring(result.passed))
