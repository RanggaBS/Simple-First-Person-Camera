LoadScript("src/utils.lua")

-- -------------------------------------------------------------------------- --
--                            Attributes & Methods                            --
-- -------------------------------------------------------------------------- --

---@class (exact) SimpleFirstPerson
---@field private __index SimpleFirstPerson
---@field new fun(sensitivity: number, options: SimpleFirstPerson_Options): SimpleFirstPerson
---@field private _isSimpleCustomThirdPersonInstalled boolean
---@field private _isCameraFOVInstalled boolean
---@field private _maxYawDeviation number -- Batas deviasi yaw relatif dari arah hadap pemain/kendaraan
---@field private _maxYaw number
---@field private _maxPitch number
---@field private _wasInVehicleLastFrame boolean -- Baru: untuk deteksi transisi keluar kendaraan
---@field private _wasInRelativeModeLastFrame boolean -- For smooth camera mode transitions
---@field private _CheckSimpleCustomThirdPersonInstalled fun(): boolean
---@field private _CheckCameraFOVInstalled fun(): boolean
---@field private _HandleSprintFOV fun(self: SimpleFirstPerson): nil
---@field private _CalculateOrientation fun(self: SimpleFirstPerson): nil
---@field private _CalculateOnFootOffset fun(self: SimpleFirstPerson): nil
---@field private _CalculateInVehicleOffset fun(self: SimpleFirstPerson): nil
---@field private _CalculateOffset fun(self: SimpleFirstPerson): nil
---@field private _CalculateCamPosAndLook fun(self: SimpleFirstPerson): nil
---@field isEnabled boolean
---@field yaw number
---@field targetYaw number
-- ---@field unclampedYaw number
---@field pitch number
---@field targetPitch number
---@field cameraRotationSmoothFactor number -- New: camera rotation smoothing factor
---@field mouseDrivenYawOffset number -- Offset yaw yang disebabkan oleh input mouse, relatif terhadap heading pemain/kendaraan
---@field offset2d ArrayOfNumbers2D
---@field pos ArrayOfNumbers3D
---@field look ArrayOfNumbers3D
---@field sensitivity number
---@field isSprintFOVEnabled boolean
---@field sprintFOVOffset number
---@field sprintFOVInterpolationSpeed number
---@field baseFOV number
---@field currentFOV number
---@field isVehicleRelativeCameraEnabled boolean -- Baru: menyimpan status opsi INI
---@field onFootAutoRotateWithPlayer boolean -- New: For controller on-foot auto rotation
---@field isAimingCamActive boolean
---@field IsEnabled fun(self: SimpleFirstPerson): boolean
---@field SetEnabled fun(self: SimpleFirstPerson, enable: boolean): nil
---@field GetSensitivity fun(self: SimpleFirstPerson): number
---@field SetSensitivity fun(self: SimpleFirstPerson, sensitivity: number): nil
---@field GetYaw fun(self: SimpleFirstPerson): number
-- ---@field GetUnclampedYaw fun(self: SimpleFirstPerson): nil
-- ---@field GetYawSameAsHeading fun(self: SimpleFirstPerson): number
---@field GetPitch fun(self: SimpleFirstPerson): number
---@field CalculateAll fun(self: SimpleFirstPerson): nil
---@field ApplyCameraTransform fun(self: SimpleFirstPerson): nil
SimpleFirstPerson = {}
SimpleFirstPerson.__index = SimpleFirstPerson

-- -------------------------------------------------------------------------- --
--                                 Constructor                                --
-- -------------------------------------------------------------------------- --

---@param sensitivity number
---@param options SimpleFirstPerson_Options
---@return SimpleFirstPerson
function SimpleFirstPerson.new(sensitivity, options)
	local instance = setmetatable({}, SimpleFirstPerson)

	instance._isSimpleCustomThirdPersonInstalled = false
	instance._isCameraFOVInstalled = false

	local sfp = SimpleFirstPerson -- Localize

	-- Create a thread that is separate from this mod thread,
	--   just for checking other mod installed or not.
	-- This runs in parallel.
	CreateThread(function()
		-- Wait a milisecond, because DSL script loads by name in ascending order..?
		--   First load SimpleFP -> then load SimpleTP
		Wait(0) -- This runs on separate thread.

		if sfp._CheckSimpleCustomThirdPersonInstalled() then --[[@diagnostic disable-line]]
			instance._isSimpleCustomThirdPersonInstalled = true --[[@diagnostic disable-line]]
			print('"Simple Custom Third Person" mod installed.')
		end

		if sfp._CheckCameraFOVInstalled() then --[[@diagnostic disable-line]]
			instance._isCameraFOVInstalled = true --[[@diagnostic disable-line]]
			print('"Camera FOV" mod installed.')
		end
	end)

	instance._maxYawDeviation = math.rad(options.maxYawDeviation)
	instance.mouseDrivenYawOffset = 0
	instance._wasInVehicleLastFrame = false
	instance._wasInRelativeModeLastFrame = false
	instance.cameraRotationSmoothFactor = options.cameraRotationSmoothFactor

	instance._maxYaw = math.rad(180)
	instance._maxPitch = math.rad(75)

	instance.isEnabled = false

	instance.yaw = 0
	instance.targetYaw = 0
	-- instance.unclampedYaw = 0
	instance.pitch = 0
	instance.targetPitch = 0

	instance.offset2d = { 0, 0 }

	instance.pos = { 0, 0, 0 }
	instance.look = { 0, 0, 0 }

	instance.sensitivity = sensitivity

	instance.isSprintFOVEnabled = options.enableSprintFOV
	instance.sprintFOVOffset = options.sprintFOVOffset
	instance.baseFOV = options.baseFOV
	instance.currentFOV = instance.baseFOV

	instance.sprintFOVInterpolationSpeed = options.sprintFOVInterpolationSpeed

	instance.isVehicleRelativeCameraEnabled =
		options.isVehicleRelativeCameraEnabled

	instance.onFootAutoRotateWithPlayer = options.onFootAutoRotateWithPlayer

	instance.isAimingCamActive = false

	return instance
end

-- -------------------------------------------------------------------------- --
--                         Local Variables & Functions                        --
-- -------------------------------------------------------------------------- --

local ANIM_SPEED_PEDSTAT_ID = 20
local MIN_SPRINT_VELOCITY = 5
local speed = 0

-- --------------------------- _HandleSprintFOV() --------------------------- --

-- local velocity = { 0, 0, 0 }
-- local vel2d = 0
-- local isTransitioning = false
-- local magnitude = 0
local isSprinting = false

-- ------------------------ _CalculateOnFootOffset() ------------------------ --

local EYES_OFFSET = 0.18
local SPRINT_OFFSET = 1.5
local RUNNING_OFFSET = 0.9
local forwardDir2d = { 0, 0 }
local dirMoveMagnitude = 0
local currentRunningOffset = 0
local facingUpDownOffset = 0

-- ----------------------- _CalculateInVehicleOffset() ---------------------- --

-- Hide Jimmy's tongue!
local VEH_OFFSET_MULT_MAP = {
	-- Bikes
	[272] = { maxSpeed = 15.5, offset = 1.845 }, -- Green BMX
	[273] = { maxSpeed = 14.2, offset = 1.725 }, -- Brown BMX
	[274] = { maxSpeed = 13.8, offset = 1.65 }, -- Crap BMX
	[275] = { maxSpeed = 22, offset = 2.4 }, -- Cop bike
	[276] = { maxSpeed = 15, offset = 1.8 }, -- Scooter
	[277] = { maxSpeed = 17, offset = 1.95 }, -- Red BMX
	[278] = { maxSpeed = 16, offset = 1.875 }, -- Blue BMX
	[279] = { maxSpeed = 13, offset = 1.65 }, -- Bicycle
	[280] = { maxSpeed = 16, offset = 2.025 }, -- Mountain bike
	[281] = { maxSpeed = 12, offset = 1.725 }, -- Lady bike
	[282] = { maxSpeed = 17, offset = 2.025 }, -- Racer bike
	[283] = { maxSpeed = 17, offset = 1.95 }, -- Aquaberry bike

	-- Car
	[286] = { maxSpeed = 24, offset = 2.175 }, -- Taxi
	[288] = { maxSpeed = 26, offset = 2.55 }, -- Dozer
	[290] = { maxSpeed = 25, offset = 2.25 }, -- Limo
	[291] = { maxSpeed = 25, offset = 2.4 }, -- Delivery Truck
	[292] = { maxSpeed = 25, offset = 2.5 }, -- Foreign Car
	[293] = { maxSpeed = 25, offset = 2.25 }, -- Regular Car
	[294] = { maxSpeed = 24, offset = 2.175 }, -- 70 Wagon
	[295] = { maxSpeed = 25, offset = 2.175 }, -- Cop Car
	[296] = { maxSpeed = 25, offset = 2.35 }, -- Domestic Car
	[297] = { maxSpeed = 25, offset = 2.475 }, -- SUV

	-- Etc
	[284] = { maxSpeed = 13, offset = 3.95 }, -- Mower
	[289] = { maxSpeed = 23, offset = 2.7 }, -- Go-Kart
	[298] = { maxSpeed = 50, offset = 3 }, -- Spaceship 1
	[287] = { maxSpeed = 50, offset = 3 }, -- Spaceship 2
	[285] = { maxSpeed = 50, offset = 3 }, -- Spaceship 3

	-- average max speed: 23.092592592593
	-- average offset = 2.2803703703704
}
local velocity3d = { 0, 0, 0 }
local offsetVehMult = 1
local vehId = 0
local vehTbl
local speedingOffset = 0
local heading = 0

-- --------------------------- _CalculateOffset() --------------------------- --

local dirMoveX, dirMoveY = 0, 0

-- ------------------------ _CalculateCamPosAndLook() ----------------------- --

local headX, headY, headZ = 0, 0, 0
local rot = { 0, 0, 0 }

-- ------------------------- _CalculateOrientation() ------------------------ --

local MOUSE_MULT = -0.01
local ctrlRotX, ctrlRotY = 0, 0
local frameTime = 0

-- -------------------------------------------------------------------------- --
--                                   Methods                                  --
-- -------------------------------------------------------------------------- --

-- --------------------------------- Private -------------------------------- --

-- Static

---@return boolean
function SimpleFirstPerson._CheckSimpleCustomThirdPersonInstalled()
	---@diagnostic disable-next-line: undefined-field
	if type(_G.SIMPLE_CUSTOM_THIRD_PERSON) == "table" then
		return true
	end
	return false
end

---@return boolean
function SimpleFirstPerson._CheckCameraFOVInstalled()
	---@diagnostic disable-next-line: undefined-field
	if type(_G.CAMERA_FOV_MOD) == "table" then
		return true
	end
	return false
end

-- Non-static

function SimpleFirstPerson:_HandleSprintFOV()
	if self.isSprintFOVEnabled then
		--[[isSprinting = false

		-- If not in any vehicle & not skateboarding
		if not PlayerIsInAnyVehicle() and PedGetWeapon(gPlayer) ~= 437 then
			-- velocity[1], velocity[2], velocity[3] = GetPlayerVelocity()
			-- magnitude = math.sqrt(velocity[1] ^ 2 + velocity[2] ^ 2)

			if
				-- magnitude > MIN_SPRINT_VELOCITY / 100 * GameGetPedStat(gPlayer, 20)
				UTIL.PlayerIsSprintingOrJumping()
			then
				isSprinting = true
			else
				isSprinting = false
			end
		end ]]

		isSprinting = not PlayerIsInAnyVehicle()
			and PedGetWeapon(gPlayer) ~= 437
			and (UTIL.PlayerIsSprinting() or PedMePlaying(gPlayer, "Jump"))
			and speed
				>= MIN_SPRINT_VELOCITY / 100 * GameGetPedStat(
					gPlayer,
					ANIM_SPEED_PEDSTAT_ID
				)

		if isSprinting then
			-- Only repeatedly change when the value is different from target value
			-- isTransitioning = true

			if CameraGetFOV() ~= self.baseFOV + self.sprintFOVOffset then
				self.currentFOV = UTIL.Lerp(
					self.currentFOV,
					self.baseFOV + self.sprintFOVOffset,
					self.sprintFOVInterpolationSpeed
				)
				CameraSetFOV(self.currentFOV)
			end
		else
			-- Only repeatedly change when the value is different from target value
			if CameraGetFOV() ~= self.baseFOV then
				-- isTransitioning = false

				self.currentFOV = UTIL.Lerp(
					self.currentFOV,
					self.baseFOV,
					self.sprintFOVInterpolationSpeed
				)
				CameraSetFOV(self.currentFOV)
			end
		end
	end
end

local lastRotate = GetTimer()

function SimpleFirstPerson:_CalculateOrientation()
	-- Controller handler
	if IsUsingJoystick(0) then
		ctrlRotX, ctrlRotY = GetStickValue(18, 0), GetStickValue(19, 0)
		ctrlRotX, ctrlRotY = ctrlRotX * 15, ctrlRotY * 15
	else
		ctrlRotX, ctrlRotY = GetMouseInput()
		ctrlRotX, ctrlRotY = ctrlRotX * 30 * MOUSE_MULT, ctrlRotY * 30 * MOUSE_MULT
	end

	frameTime = GetFrameTime()

	local smoothingFactor = self.cameraRotationSmoothFactor

	self.targetPitch = self.targetPitch + ctrlRotY * self.sensitivity * frameTime
	self.targetPitch =
		UTIL.Clamp(self.targetPitch, -self._maxPitch, self._maxPitch)
	self.pitch = UTIL.Lerp(self.pitch, self.targetPitch, smoothingFactor)

	local isInVehicleThisFrame = PlayerIsInAnyVehicle()
	local isController = IsUsingJoystick(0)

	-- On exit vehicle
	if
		self._wasInVehicleLastFrame
		and not isInVehicleThisFrame
		and self.isVehicleRelativeCameraEnabled
	then
		self.mouseDrivenYawOffset = 0
		self.yaw = UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
	end

	-- On bicycling or driving car
	if self.isVehicleRelativeCameraEnabled and isInVehicleThisFrame then
		self.mouseDrivenYawOffset = self.mouseDrivenYawOffset
			+ ctrlRotX * self.sensitivity * frameTime

		self.mouseDrivenYawOffset = UTIL.Clamp(
			self.mouseDrivenYawOffset,
			-self._maxYawDeviation,
			self._maxYawDeviation
		)

		local baseHeading = UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
		self.targetYaw = baseHeading + self.mouseDrivenYawOffset

		local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
		self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)
	end

	local activateOnFootAutoRotate = self.onFootAutoRotateWithPlayer
		and not isInVehicleThisFrame
		and isController

	local isRelativeModeThisFrame = (
		self.isVehicleRelativeCameraEnabled and isInVehicleThisFrame
	) or activateOnFootAutoRotate

	if isRelativeModeThisFrame and not self._wasInRelativeModeLastFrame then
		self.mouseDrivenYawOffset = 0
		self.yaw = UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
	elseif not isRelativeModeThisFrame and self._wasInRelativeModeLastFrame then
		-- Transitioning FROM relative mode
		-- self.yaw is already absolute (world-relative) due to previous calculation,
		-- so it's a good starting point for absolute mode.
		-- mouseDrivenYawOffset will be set to 0 if not in relative mode.
	end

	-- On foot
	if not isInVehicleThisFrame then
		if isRelativeModeThisFrame then
			self.mouseDrivenYawOffset = self.mouseDrivenYawOffset
				+ ctrlRotX * self.sensitivity * frameTime

			self.mouseDrivenYawOffset = UTIL.Clamp(
				self.mouseDrivenYawOffset,
				-self._maxYawDeviation,
				self._maxYawDeviation
			)

			-- If analog moving
			if math.abs(GetStickValue(18, 0)) > 0 then
				lastRotate = GetTimer()
			end

			-- The delay before the camera direction follows the player facing direction
			local DELAY = math.random(750, 1000)

			-- If standing still, no moving
			-- Prevent player looking 360°
			if UTIL.GetWholeStickValue() <= 0 then
				self.mouseDrivenYawOffset = self.mouseDrivenYawOffset
					+ ctrlRotX * self.sensitivity * frameTime

				self.mouseDrivenYawOffset = UTIL.Clamp(
					self.mouseDrivenYawOffset,
					-self._maxYawDeviation,
					self._maxYawDeviation
				)

				local baseHeading =
					UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
				self.targetYaw = baseHeading + self.mouseDrivenYawOffset

				local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
				self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)

			--[[ -- Freely rotate the camera
			elseif GetTimer() < lastRotate + DELAY then
				self.targetYaw = self.targetYaw
					+ ctrlRotX * self.sensitivity * frameTime
				self.yaw = UTIL.Lerp(self.yaw, self.targetYaw, smoothingFactor)
				self.mouseDrivenYawOffset = 0 ]]

			--[[ -- If right analog not moving, not rotating the camera
			--   Camera direction follows the player facing direction
			elseif math.abs(GetStickValue(18, 0)) <= 0 then
				local baseHeading =
					UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))

				self.targetYaw = baseHeading + self.mouseDrivenYawOffset -- Ini adalah 'tujuan' yaw, bisa di luar (-PI, PI]

				-- `currentActualYaw` adalah orientasi kamera dari frame sebelumnya.
				-- Sebaiknya dijaga dalam rentang kanonis, misal dengan UTIL.FixRadians di akhir update frame lalu.
				local currentActualYaw = self.yaw

				-- Hitung perbedaan sudut antara target dan yaw saat ini
				local diff = self.targetYaw - currentActualYaw

				-- Normalisasi perbedaan sudut agar selalu mengambil jalur terpendek (-PI sampai PI)
				diff = UTIL.FixRadians(diff)

				-- Target untuk interpolasi adalah yaw saat ini ditambah dengan perbedaan terpendek
				local adjustedTargetForLerp = currentActualYaw + diff

				self.yaw =
					UTIL.Lerp(currentActualYaw, adjustedTargetForLerp, smoothingFactor) -- Interpolasi sepanjang jalur terpendek

				-- Opsional tapi direkomendasikan: Jaga self.yaw dalam rentang standar (-PI, PI].
				-- Ini tidak berdampak negatif pada kalkulasi cos/sin frame ini,
				-- dan memastikan self.yaw untuk frame berikutnya dimulai dari representasi kanonis.
				-- Juga berguna untuk debugging jika Anda mencetak nilai self.yaw.
				self.yaw = UTIL.FixRadians(self.yaw) ]]

			-- If player moving around
			else
				if GetTimer() < lastRotate + DELAY then
					local yaw = self.targetYaw + ctrlRotX * self.sensitivity * frameTime
					self.targetYaw = UTIL.FixRadians(yaw)
				--
				else
					self.mouseDrivenYawOffset = 0

					local baseHeading =
						UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
					self.targetYaw = baseHeading + self.mouseDrivenYawOffset
				end

				local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
				self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)
			end

		-- Keyboard & mouse
		else
			-- If mouse moving horizontally
			local mouseX, mouseY = GetMouseInput()
			if mouseX ~= 0 then
				lastRotate = GetTimer()
			end

			local DELAY = math.random(750, 1000)

			-- If not moving, standing still
			if UTIL.GetWholeStickValue() <= 0 then
				self.mouseDrivenYawOffset = self.mouseDrivenYawOffset
					+ ctrlRotX * self.sensitivity * frameTime

				self.mouseDrivenYawOffset = UTIL.Clamp(
					self.mouseDrivenYawOffset,
					-self._maxYawDeviation,
					self._maxYawDeviation
				)

				local baseHeading =
					UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
				self.targetYaw = baseHeading + self.mouseDrivenYawOffset

				local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
				self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)
			-- elseif GetTimer() < lastRotate + DELAY and UTIL.GetWholeStickValue() <= 0 then
			-- 	local newYaw = self.targetYaw + ctrlRotX * self.sensitivity * frameTime
			-- 	self.targetYaw = newYaw
			-- 	self.yaw = UTIL.Lerp(self.yaw, newYaw, smoothingFactor)
			-- 	self.mouseDrivenYawOffset = 0

			-- If moving
			else
				-- Freely move rotate the camera around with mouse
				if GetTimer() < lastRotate + DELAY then
					self.targetYaw = UTIL.FixRadians(
						self.targetYaw + ctrlRotX * self.sensitivity * frameTime
					)

					local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
					self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)

				-- If past than the timer...
				--   The camera rotation now relative to the player heading
				else
					self.mouseDrivenYawOffset = 0

					local baseHeading =
						UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
					self.targetYaw = baseHeading + self.mouseDrivenYawOffset

					local diff = UTIL.FixRadians(self.targetYaw - self.yaw)
					self.yaw = UTIL.Lerp(self.yaw, self.yaw + diff, smoothingFactor)
				end
			end
		end
	end

	self._wasInVehicleLastFrame = isInVehicleThisFrame -- Keep for other logic if needed
	self._wasInRelativeModeLastFrame = isRelativeModeThisFrame -- Update state for next frame
end

function SimpleFirstPerson:_CalculateOnFootOffset()
	if not PlayerIsInAnyVehicle() then
		if UTIL.PlayerIsSprinting() then
			self.offset2d[1] = forwardDir2d[1] * EYES_OFFSET * SPRINT_OFFSET
			self.offset2d[2] = forwardDir2d[2] * EYES_OFFSET * SPRINT_OFFSET
		else
			currentRunningOffset = UTIL.Clamp(
				UTIL.Lerp(0, RUNNING_OFFSET, dirMoveMagnitude),
				0,
				RUNNING_OFFSET
			)

			-- If running around (not sprinting)
			if dirMoveMagnitude > 0 then
				self.offset2d[1] = forwardDir2d[1] * EYES_OFFSET * currentRunningOffset
				self.offset2d[2] = forwardDir2d[2] * EYES_OFFSET * currentRunningOffset

			-- If idle
			else
				self.offset2d[1] = forwardDir2d[1] * EYES_OFFSET * facingUpDownOffset
				self.offset2d[2] = forwardDir2d[2] * EYES_OFFSET * facingUpDownOffset
			end
		end
	end
end

function SimpleFirstPerson:_CalculateInVehicleOffset()
	if PlayerIsInAnyVehicle() then
		-- Don't move the camera to the front when pressing move left, move right,
		-- and move back button.
		--[[ if dirMoveX ~= 0 then
			dirMoveX = 0
		end
		if dirMoveY < 0 then
			dirMoveY = 0
		end ]]

		-- Weird result from the speed calculation? Just reset it.
		-- In this game, no vehicle is capable of speeding beyond this speed,
		-- except spaceships (minigame arcade vehicle), or your modified vehicle
		-- speed in "Config/handling.cfg".
		--[[ if maxVel >= 50 then
			maxVel = 0
		end ]]

		vehId = VehicleGetModelId(VehicleFromDriver(gPlayer) --[[@as integer]])
		vehTbl = VEH_OFFSET_MULT_MAP[vehId]
		if not vehTbl then
			vehTbl = { maxSpeed = 23.092592592593, offset = 2.2803703703704 } -- avg speed & offset
		end

		offsetVehMult = UTIL.Clamp(
			UTIL.Lerp(1, vehTbl.offset, speed / vehTbl.maxSpeed),
			1,
			vehTbl.maxSpeed
		)

		speedingOffset =
			UTIL.Clamp(UTIL.Lerp(0, 1, (speed / vehTbl.maxSpeed) * 1.5), 0, 1)

		local minSpeedingFactor = 0.7
		local actualSpeedingOffset = UTIL.Lerp(minSpeedingFactor, 1, speedingOffset)

		if speed > 0.2 then -- If moving
			-- If pressing move forward button
			self.offset2d[1] = forwardDir2d[1]
				* EYES_OFFSET
				* actualSpeedingOffset
				* offsetVehMult
			self.offset2d[2] = forwardDir2d[2]
				* EYES_OFFSET
				* actualSpeedingOffset
				* offsetVehMult

			-- If pressing move back button, slightly move the camera to the back
			if UTIL.GetForwardBackwardVelocity(heading) < -0.1 then
				-- Don't if driving cop bike or scooter
				if vehId == 275 or vehId == 276 then
					self.offset2d[1] = 0
					self.offset2d[2] = 0

				-- Otherwise move back
				else
					self.offset2d[1] = -forwardDir2d[1] * EYES_OFFSET * 0.8
					self.offset2d[2] = -forwardDir2d[2] * EYES_OFFSET * 0.8
				end
			end
		else -- If not moving (or very slow)
			self.offset2d[1] = forwardDir2d[1] * EYES_OFFSET * facingUpDownOffset
			self.offset2d[2] = forwardDir2d[2] * EYES_OFFSET * facingUpDownOffset
		end
	end
end

function SimpleFirstPerson:_CalculateOffset()
	-- Calculate local shared variable here

	heading = PedGetHeading(gPlayer)
	forwardDir2d[1], forwardDir2d[2] = -math.sin(heading), math.cos(heading)

	-- Multiplication is faster to compute than division, am I right?
	-- x * 0.5 == x / 2

	-- Move slightly forward when looking down & don't move the camera to the
	-- back of the player's head when looking upwards.
	facingUpDownOffset = UTIL.Clamp(-self.pitch * 0.5, 0, 1)

	dirMoveX, dirMoveY = UTIL.GetDirectionalMovement()

	-- Between 0 - 1
	dirMoveMagnitude = math.sqrt(dirMoveX ^ 2 + dirMoveY ^ 2)

	-- Local shared variable is now updated with the new value & ready to be used
	-- inside below functions.

	self:_CalculateOnFootOffset()
	self:_CalculateInVehicleOffset()
end

function SimpleFirstPerson:_CalculateCamPosAndLook()
	headX, headY, headZ = PedGetHeadPos(gPlayer)
	headZ = headZ + 0.1 -- Aligned to the eyes position

	-- The rotation formula
	rot[1] = math.cos(self.yaw) * math.cos(self.pitch)
	rot[2] = math.sin(self.yaw) * math.cos(self.pitch)
	rot[3] = math.sin(self.pitch)

	-- Calculate camera position
	self.pos[1] = headX + self.offset2d[1]
	self.pos[2] = headY + self.offset2d[2]
	self.pos[3] = headZ

	-- Calculate camera look at position
	self.look[1] = headX + self.offset2d[1] + rot[1]
	self.look[2] = headY + self.offset2d[2] + rot[2]
	self.look[3] = headZ + rot[3]
end

local lastAimBtnPressed = GetTimer()

function SimpleFirstPerson:_HandleAimingCameraActivation()
	if GetTimer() < lastAimBtnPressed + 300 and IsButtonBeingPressed(10, 0) then
		self.isAimingCamActive = true
		local sfp = self

		CreateThread(function()
			PlayerStopAllActionControllers()
			Wait(0)
			PlayerStopAllActionControllers()

			local startAiming = GetTimer()
			local holding = false

			while
				not IsButtonBeingPressed(10, 0) or (holding and IsButtonPressed(10, 0))
			do
				Wait(0)

				local isInTreshold = GetTimer() < startAiming + 150
				if isInTreshold and IsButtonBeingPressed(10, 0) then
					holding = true
				elseif not isInTreshold and IsButtonBeingReleased(10, 0) then
					break
				end

				sfp.isEnabled = false
				if CameraGetActive() ~= 2 then
					CameraSetActive(2)
				end
				lastAimBtnPressed = GetTimer()
			end

			sfp.isAimingCamActive = false
			sfp.isEnabled = true

			sfp.yaw = UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
			sfp.targetYaw = sfp.yaw
			sfp.pitch = 0
			sfp.targetPitch = 0

			CameraSetActive(4) -- back to simplefp camera
		end)
	--
	elseif IsButtonBeingPressed(10, 0) then
		lastAimBtnPressed = GetTimer()
	end
end

-- --------------------------------- Public --------------------------------- --

-- Non-static

---@return boolean
function SimpleFirstPerson:IsEnabled()
	return self.isEnabled
end

---@param enable boolean
function SimpleFirstPerson:SetEnabled(enable)
	self.isEnabled = enable

	if enable then
		-- Disable Third Person if Simple Custom Third Person is installed
		if self._isSimpleCustomThirdPersonInstalled then
			_G.SIMPLE_CUSTOM_THIRD_PERSON.GetSingleton():SetEnabled(false)
		end
		-- if self._isCameraFOVInstalled then
		-- 	_G.CAMERA_FOV_MOD.GetSingleton():SetEnabled(false)
		-- end

		self._wasInVehicleLastFrame = PlayerIsInAnyVehicle()
		local isController = IsUsingJoystick(0)
		local activateOnFootAutoRotate = self.onFootAutoRotateWithPlayer
			and not self._wasInRelativeModeLastFrame
			and isController
		self._wasInRelativeModeLastFrame = (
			self.isVehicleRelativeCameraEnabled and self._wasInVehicleLastFrame
		) or activateOnFootAutoRotate

		-- Reset
		self.mouseDrivenYawOffset = 0
		self.pitch = 0

		self.yaw = UTIL.FixRadians(PedGetHeading(gPlayer) + math.rad(90))
	else
		self.currentFOV = self.baseFOV
		CameraDefaultFOV()
		CameraAllowChange(true)
		CameraReturnToPlayer()
	end
end

---@return number
function SimpleFirstPerson:GetSensitivity()
	return self.sensitivity
end

---@param sensitivity number
function SimpleFirstPerson:SetSensitivity(sensitivity)
	self.sensitivity = sensitivity * 0.1
end

---@return number
function SimpleFirstPerson:GetYaw()
	return self.yaw
end

-- ---@return number
-- function SimpleFirstPerson:GetUnclampedYaw()
-- 	return self.unclampedYaw
-- end

--[[ ---@return number
function SimpleFirstPerson:GetYawSameAsHeading()
	local yawInDegree = math.deg(self.yaw)
	local yawSameAsHeading = yawInDegree - 90
	if yawSameAsHeading <= -180 then
		yawSameAsHeading = 270 - (yawInDegree + 540)
	end
	-- yawSameAsHeading = math.abs(yawSameAsHeading)
	-- if PedGetHeading(gPlayer) < 0 then
	-- 	yawSameAsHeading = -yawSameAsHeading
	-- end
	return math.rad(yawSameAsHeading)
end ]]

---@return number
function SimpleFirstPerson:GetPitch()
	return self.pitch
end

function SimpleFirstPerson:CalculateAll()
	-- Update local shared variables

	velocity3d[1], velocity3d[2], velocity3d[3] = UTIL.GetPlayerVelocity()
	speed = math.sqrt(velocity3d[1] ^ 2 + velocity3d[2] ^ 2 + velocity3d[3] ^ 2)

	-- Local shared variable is now updated with the new value & ready to be used
	-- inside below functions.

	self:_CalculateOrientation()
	self:_CalculateOffset()
	self:_CalculateCamPosAndLook()
	self:_HandleSprintFOV()
end

function SimpleFirstPerson:ApplyCameraTransform()
	CameraSetXYZ(
		self.pos[1],
		self.pos[2],
		self.pos[3],
		self.look[1],
		self.look[2],
		self.look[3]
	)
	CameraAllowChange(false)
end

-- -------------------------------------------------------------------------- --
-- Type Definition                                                            --
-- -------------------------------------------------------------------------- --

---@alias SimpleFirstPerson_Options { enableSprintFOV: boolean, baseFOV: number, sprintFOVOffset: number, sprintFOVInterpolationSpeed: number, isVehicleRelativeCameraEnabled: boolean, maxYawDeviation: number, onFootAutoRotateWithPlayer: boolean, cameraRotationSmoothFactor: number }
