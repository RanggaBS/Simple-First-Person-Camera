-- Disable the first person camera when a cutscene is about to play
HookFunction("LoadCutscene", function()
	-- Logging
	-- print("Simple First Person: disabled for cutscene.")

	SIMPLE_FIRST_PERSON.GetSingleton():SetEnabled(false)
end)
