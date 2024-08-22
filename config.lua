polling_seconds = 5
create_test_accounts = 10
script_engine_workflow_rest_url = "http://dockermain:5195/api/ProcessWorkflow/"

mongo = {
	url = "mongodb://dolbeyadmin:fusion@dockermain:27095/admin",
	database = "FusionCAC2",
}

-- Define a base set of scripts.
-- Other config files are expected to execute this one and then modify the script table.
scripts = {
	["scripts/substance_abuse.lua"] = {
		criteria_group = "Substance Abuse",
	},
	["scripts/atrial_fibrillation.lua"] = {
		criteria_group = "Atrial Fibrillation",
	},
	["scripts/abnormal_serum_calcium.lua"] = {
		criteria_group = "Abnormal Serum Calcium",
	},
	["scripts/abnormal_serum_potassium.lua"] = {
		criteria_group = "Abnormal Serum Potassium",
	},
	["scripts/abnormal_serum_sodium.lua"] = {
		criteria_group = "Abnormal Serum Sodium",
	},
	["scripts/acidosis.lua"] = {
		criteria_group = "Acidosis",
	},
	["scripts/anemia.lua"] = {
		criteria_group = "Anemia",
	},
	["scripts/acute_mi_troponemia.lua"] = {
		criteria_group = "Acute MI Troponemia",
	},
}
