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
	local toggleHeadKey = config:GetSettingValue("sToggleHeadKey") --[[@as string]]

	local BODYPART_HEAD = 0

	local prevHat = UTIL.GetCurrentHeadClothingName()

	while true do
		Wait(0)

		if MOD.IsEnabled() then
			if GetCutsceneRunning() == 0 then
				if modifierKey ~= "none" then
					if IsKeyPressed(modifierKey) and IsKeyBeingPressed(activationKey) then
						SimpleFP:SetEnabled(not SimpleFP:IsEnabled())

						-- Restore head back
						if not SimpleFP:IsEnabled() then
							ClothingSetPlayer(BODYPART_HEAD, prevHat or "HAIR")
							ClothingBuildPlayer()
						end
					end
				else
					if IsKeyBeingPressed(activationKey) then
						SimpleFP:SetEnabled(not SimpleFP:IsEnabled())

						-- Restore head back
						if not SimpleFP:IsEnabled() then
							ClothingSetPlayer(BODYPART_HEAD, prevHat or "HAIR")
							ClothingBuildPlayer()
						end
					end
				end

				if SimpleFP:IsEnabled() then
					SimpleFP:CalculateAll()
					SimpleFP:ApplyCameraTransform()

					-- Fix: camera facing the wrong direction after entering building
					if AreaIsLoading() then
						local prevArea = AreaGetVisible()
						while AreaIsLoading() do
							Wait(0)
							SimpleFP:CalculateAll()
							SimpleFP:ApplyCameraTransform()
						end
						if AreaGetVisible() ~= prevArea then
							SimpleFP.yaw = PedGetHeading(gPlayer) + math.rad(90)
						end
					end

					-- Toggle head
					if IsKeyBeingPressed(toggleHeadKey) then
						local clthHash, clthId = ClothingGetPlayer(BODYPART_HEAD)
						local isInvalid = tostring(clthHash) == "userdata: 00000000"

						-- If head invisible
						if isInvalid then
							ClothingSetPlayer(BODYPART_HEAD, prevHat or "HAIR") -- Must be all uppercase! "HAIR"
							ClothingBuildPlayer()

						-- If head visible
						else
							-- Backup hat
							prevHat = "HAIR"
							if UTIL.IsWearingHat() then
								prevHat = UTIL.GetCurrentHeadClothingName()
							end

							ClothingSetPlayer(BODYPART_HEAD, "") -- Empty string, invalid clothing - makes Jimmy headless
							ClothingBuildPlayer()
						end
					end
				end
			end
		end
	end
end
