--[[
	A modification script for Bully SE game

	Mod name: Simple First Person Camera
	Author: RBS ID

	Requirements:
		- Derpy's Script Loader v7 or greater
]]

-- Header

RequireLoaderVersion(7)

-- -------------------------------------------------------------------------- --
--                                 Entry Point                                --
-- -------------------------------------------------------------------------- --

function main()
	while not SystemIsReady() do
		Wait(0)
	end

	LoadScript("src/setup.lua")
	LoadScript("src/hook.lua")

	local MOD = SIMPLE_FIRST_PERSON

	MOD.Init()

	local SimpleFP = MOD.GetSingleton()
	local config = MOD._INTERNAL.INSTANCE.Config --[[@diagnostic disable-line]]

	local activationKey = config:GetSettingValue("sKeycode") --[[@as string]]
	local modifierKey = config:GetSettingValue("sModifierKey") --[[@as string]]

	while true do
		Wait(0)

		if MOD.IsEnabled() then
			if GetCutsceneRunning() == 0 then
				if modifierKey ~= "none" then
					if IsKeyPressed(modifierKey) and IsKeyBeingPressed(activationKey) then
						SimpleFP:SetEnabled(not SimpleFP:IsEnabled())
					end
				else
					if IsKeyBeingPressed(activationKey) then
						SimpleFP:SetEnabled(not SimpleFP:IsEnabled())
					end
				end

				if SimpleFP:IsEnabled() then
					SimpleFP:CalculateAll()
					SimpleFP:ApplyCameraTransform()
				end
			end
		end
	end
end
