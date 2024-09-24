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
}
