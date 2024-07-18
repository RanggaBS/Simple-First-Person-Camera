-- -------------------------------------------------------------------------- --
--                        Utilities / Helper Functions                        --
-- -------------------------------------------------------------------------- --

UTIL = {}

---@param v number
---@param min number
---@param max number
---@return number
function UTIL.Clamp(v, min, max)
	return v < min and min or v > max and max or v
end

---@param v number
---@param min number
---@param max number
---@param ifmin number
---@param ifmax number
---@return number
function UTIL.Clamp2(v, min, max, ifmin, ifmax)
	return v < min and ifmin or v > max and ifmax or v
end

---Reference:
---[Code](https://help.interfaceware.com/v6/extract-a-filename-from-a-file-path),
---[Regex](https://onecompiler.com/lua/3zzskbj4q)
---@param path string
---@return string
function GetFilenameWithExtensionFromPath(path)
	local startIndex, _ = string.find(path, "[^%\\/]-$")
	---@diagnostic disable-next-line: param-type-mismatch
	return string.sub(path, startIndex, string.len(path))
end

---@return number, number
function UTIL.GetDirectionalMovement()
	local leftRight, forwardBackward = -GetStickValue(16, 0), GetStickValue(17, 0)
	-- return leftRight + forwardBackward
	return leftRight, forwardBackward
end

---@param a number
---@param b number
---@return number
function modulo(a, b)
	return a - math.floor(a / b) * b
end

---@param word string
---@return string
function CapitalizeFirstLetter(word)
	return string.upper(string.sub(word, 1, 1))
		.. string.sub(word, 2, string.len(word))
end

local playerPos = { 0, 0, 0 }
local playerLastPos = { 0, 0, 0 }
local playerVelocity = { 0, 0, 0 }
local frameTime = 0
---Don't call this function twice, otherwise it'll always return 0.
---@return number velocityX, number velocityY, number velocityZ
function UTIL.GetPlayerVelocity()
	-- Update last position
	for axis = 1, 3 do
		playerLastPos[axis] = playerPos[axis]
	end

	playerPos[1], playerPos[2], playerPos[3] = PlayerGetPosXYZ()

	frameTime = GetFrameTime()

	for axis = 1, 3 do
		playerVelocity[axis] = (playerPos[axis] - playerLastPos[axis]) / frameTime
	end

	return unpack(playerVelocity)
end

---@param a number
---@param b number
---@param t number
---@return number
function Lerp(a, b, t)
	return a + (b - a) * t
end

local DIGITS_PRECISION_TOLERANCY = 0.01
---@param a number
---@param b number
---@param t number
---@return number
function UTIL.LerpOptimized(a, b, t)
	local lerp = Lerp(a, b, t)

	if b < 0 then
		-- if (-v < -b) && (-v > -b) - 0.01
		if lerp < b and lerp > b - DIGITS_PRECISION_TOLERANCY then
			return b

		-- if (-v > -b) && (-v < -b) + 0.01
		elseif lerp > b and lerp < b + DIGITS_PRECISION_TOLERANCY then
			return b
		end
	--
	elseif b > 0 then
		-- if (v < b) && (v > b) - 0.01
		if lerp < b and lerp > b - DIGITS_PRECISION_TOLERANCY then
			return b

		-- if (v > b) && (v < b) + 0.01
		elseif lerp > b and lerp < b + DIGITS_PRECISION_TOLERANCY then
			return b
		end
	end

	return lerp
end

local lastSprintPressed = GetTimer()
local DELAY = 300
function UTIL.PlayerIsSprinting()
	if
		math.abs(GetStickValue(16, 0)) > 0 or math.abs(GetStickValue(17, 0)) > 0
	then
		if IsButtonPressed(7, 0) then
			lastSprintPressed = GetTimer()
			return true
		elseif
			GetTimer()
			< lastSprintPressed + DELAY * 100 / GameGetPedStat(gPlayer, 20)
		then
			return true
		end
	end
	return false
end

local vel2d = { 0, 0 }
local dirX, dirY = 0, 0
local dotProd = 0
---Get velocity value whether is moving forward or backward based on `heading`.
---
---Positive: moving forward, negative: moving backward
---
---[See reference](https://forum.unity.com/threads/3d-how-determine-if-car-is-driving-backwards.1261817/)
---@param heading number in radians
---@return number
function UTIL.GetForwardBackwardVelocity(heading)
	-- Velocity vector
	vel2d[1], vel2d[2], _ = unpack(playerVelocity) -- Not calling `GetPlayerVelocity`

	-- Get forward vector (basically it's just 1 meter in front of object with
	-- `heading` as facing direction)
	dirX, dirY = -math.sin(heading), math.cos(heading)

	-- Dot product of the 2 vector
	dotProd = vel2d[1] * dirX + vel2d[2] * dirY

	return dotProd
end

---@param rads number
---@return number
function UTIL.FixRadians(rads) -- keep radians between -pi and pi.
	while rads > math.pi do
		rads = rads - math.pi * 2
	end
	while rads <= -math.pi do
		rads = rads + math.pi * 2
	end
	return rads
end
