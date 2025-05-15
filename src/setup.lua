for _, filename in ipairs({
	"Config",
	"DSLCommandManager",
	"SimpleFirstPerson",
}) do
	LoadScript("src/" .. filename .. ".lua")
end

-- -------------------------------------------------------------------------- --
--                                 Attributes                                 --
-- -------------------------------------------------------------------------- --

---@class SIMPLE_FIRST_PERSON
---@field private _INTERNAL table
local privateFields = {
	-- Private. You shouldn't try to access/index this directly in your script even
	-- if you know the keys.
	_INTERNAL = {
		INITIALIZED = false,

		CONFIG = {
			FILENAME_WITH_EXTENSION = "settings.ini",
			DEFAULT_SETTING = {
				bEnabled = false,
				bEnableFirstPerson = false,

				sToggleHeadKey = "H",
				sKeycode = "F",
				sModifierKey = "LSHIFT",
				fLookSensitivity = 1.5,

				bEnableSprintFOV = true,
				fFOV = 90,
				fSprintFOVOffset = 20,
				fSprintFOVInterpolationSpeed = 0.1,
			},
		},

		COMMAND = {
			NAME = "simplefp",
			HELP_TEXT = [[simplefp

Usage:
  - simplefp <toggle> (Enable/disable the mod, where <toggle> must be "enable" or "disable")
  - simplefp set sensitivity <value> (Set the camera look sensitivity, <value> must be numbers)]],
		},

		INSTANCE = {
			---@type Config
			Config = nil,

			---@type SimpleFirstPerson
			SimpleFirstPerson = nil,
		},
	},
}

-- -------------------------------------------------------------------------- --
--                           Private Static Methods                           --
-- -------------------------------------------------------------------------- --

function privateFields._RegisterCommand()
	local command = privateFields._INTERNAL.COMMAND
	local instance = privateFields._INTERNAL.INSTANCE

	---@param value string
	---@param argType string
	---@return boolean
	local function checkIfArgSpecified(value, argType)
		if not value or value == "" then
			PrintError(argType .. " didn't specified.")
			return false
		end

		return true
	end

	---@param value string
	---@return boolean
	local function isFirstArgValid(value)
		if not checkIfArgSpecified(value, "Command action type") then
			return false
		end

		if
			not ({
				["enable"] = true,
				["disable"] = true,
				["set"] = true,
			})[string.lower(value)]
		then
			PrintError('Allowed command action types are "enable"|"disable"|"set".')
			return false
		end

		return true
	end

	---@param value string
	---@return boolean
	local function isSecondArgValid(value)
		if not checkIfArgSpecified(value, "Key setting") then
			return false
		end

		if not ({ ["sensitivity"] = true })[string.lower(value)] then
			PrintError('Key must be "sensitivity".')
			return false
		end

		return true
	end

	---@param value string
	---@return boolean
	local function isThirdArgValid(value)
		if not checkIfArgSpecified(value, "Number didn't specified.") then
			return false
		end

		if not tonumber(value) then
			PrintError("Invalid number.")
			return false
		end

		return true
	end

	if DSLCommandManager.IsAlreadyExist(command.NAME) then
		DSLCommandManager.Unregister(command.NAME)
	end

	DSLCommandManager.Register(command.NAME, function(...)
		local actionType = arg[1]
		local keySetting = arg[2]
		local sensitivityValue = arg[3]

		if not isFirstArgValid(actionType) then
			return
		end

		actionType = string.lower(actionType)

		-- Toggle ON/OFF
		if actionType == "enable" or actionType == "disable" then
			SIMPLE_FIRST_PERSON.SetEnabled(actionType == "enable")
			print("Simple First Person: Mod " .. actionType .. "d.")

		-- Set sensitivity
		else
			if
				not (isSecondArgValid(keySetting) and isThirdArgValid(sensitivityValue))
			then
				return
			end

			instance.SimpleFirstPerson:SetSensitivity(
				tonumber(sensitivityValue) --[[@as number]]
			)
			print(
				"Simple First Person: Sensitivity set to " .. tostring(sensitivityValue)
			)
		end
	end, {
		rawArgument = false,
		helpText = command.HELP_TEXT,
	})
end

-- -------------------------------------------------------------------------- --

-- Hide all the above key/attribute from `pairs()`.

-- Using `_G` notation to create a global variable that can be accessed across
-- different scripts.

privateFields.__index = privateFields

---@class SIMPLE_FIRST_PERSON
_G.SIMPLE_FIRST_PERSON = setmetatable({
	VERSION = "1.1.0",

	DATA = {
		-- The core mod state. If `false`, you cannot switch to first person POV.
		-- This can be toggled only via console.
		IS_ENABLED = true,
	},
}, privateFields)

-- -------------------------------------------------------------------------- --
--                         Public Static Methods / API                        --
-- -------------------------------------------------------------------------- --

local internal = SIMPLE_FIRST_PERSON._INTERNAL
local instance = internal.INSTANCE

---@return SimpleFirstPerson
function SIMPLE_FIRST_PERSON.GetSingleton()
	if not instance.SimpleFirstPerson then
		local conf = instance.Config

		instance.SimpleFirstPerson = SimpleFirstPerson.new(
			conf:GetSettingValue("fLookSensitivity") --[[@as number]],
			{
				enableSprintFOV = conf:GetSettingValue("bEnableSprintFOV") --[[@as boolean]],
				sprintFOVOffset = conf:GetSettingValue("fSprintFOVOffset") --[[@as number]],
				sprintFOVInterpolationSpeed = conf:GetSettingValue(
					"fSprintFOVInterpolationSpeed"
				) --[[@as number]],
				baseFOV = conf:GetSettingValue("fFOV") --[[@as number]],
			}
		)

		instance.SimpleFirstPerson:SetEnabled(
			conf:GetSettingValue("bEnableFirstPerson") --[[@as boolean]]
		)
		instance.SimpleFirstPerson:SetSensitivity(
			conf:GetSettingValue("fLookSensitivity") --[[@as number]]
		)
	end

	return instance.SimpleFirstPerson
end

function SIMPLE_FIRST_PERSON.Init()
	if not internal.INITIALIZED then
		-- Create & get instances

		instance.Config = Config.new(
			"src/" .. internal.CONFIG.FILENAME_WITH_EXTENSION,
			internal.CONFIG.DEFAULT_SETTING
		)

		instance.SimpleFirstPerson = SIMPLE_FIRST_PERSON.GetSingleton()

		SIMPLE_FIRST_PERSON._RegisterCommand()

		SIMPLE_FIRST_PERSON.DATA.IS_ENABLED =
			instance.Config:GetSettingValue("bEnabled") --[[@as boolean]]
		-- Delete

		SimpleFirstPerson = nil ---@diagnostic disable-line
		Config = nil ---@diagnostic disable-line

		collectgarbage()

		internal.INITIALIZED = true
	end
end

---@return string
function SIMPLE_FIRST_PERSON.GetVersion()
	return SIMPLE_FIRST_PERSON.VERSION
end

---@return boolean
function SIMPLE_FIRST_PERSON.IsInstalled()
	return true
end

---@return boolean
function SIMPLE_FIRST_PERSON.IsEnabled()
	return SIMPLE_FIRST_PERSON.DATA.IS_ENABLED
end

---@param enable boolean
function SIMPLE_FIRST_PERSON.SetEnabled(enable)
	SIMPLE_FIRST_PERSON.DATA.IS_ENABLED = enable

	-- If the mod is set to disabled..
	if not enable then
		-- ..then disable first person POV as well
		instance.SimpleFirstPerson:SetEnabled(false)
	end
end
