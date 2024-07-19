---@diagnostic disable: missing-return

-- DO NOT LOAD THIS SCRIPT!

---@alias CameraFOV_Area "world"|"interior"
---@alias CameraFOV_Options { worldFOV?: number, interiorFOV?: number, overrideCutsceneFOV?: boolean }

---@class CameraFOV
---@field new fun(enable: boolean, options?: CameraFOV_Options): CameraFOV
---@field private _isSimpleFirstPersonInstalled boolean
---@field private _isSimpleCustomThirdPersonInstalled boolean
---@field private _CheckSimpleFirstPersonInstalled fun(): boolean
---@field private _CheckSimpleCustomThirdPersonInstalled fun(): boolean
---@field isEnabled boolean
---@field worldFOV number
---@field interiorFOV number
---@field shouldOverrideCutsceneFOV boolean
---@field IsEnabled fun(self: CameraFOV): boolean
---@field SetEnabled fun(self: CameraFOV, enable: boolean): nil
---@field IsCutsceneFOVOverriden fun(self: CameraFOV): boolean
---@field SetOverrideCutsceneFOV fun(self: CameraFOV, enable: boolean): nil
---@field GetWorldFOV fun(self: CameraFOV): number
---@field SetWorldFOV fun(self: CameraFOV, fov: number): nil
---@field GetInteriorFOV fun(self: CameraFOV): number
---@field SetInteriorFOV fun(self: CameraFOV, fov: number): nil
---@field GetFOVInArea fun(self: CameraFOV, area: CameraFOV_Area): number
---@field GetFOVInAreaId fun(self: CameraFOV, areaId: integer): number
---@field GetFOVInCurrentArea fun(self: CameraFOV): number
---@field SetFOVInArea fun(self: CameraFOV, area: CameraFOV_Area, fov: number): nil
---@field SetFOVInAreaId fun(self: CameraFOV, areaId: integer, fov: number): nil
---@field ApplyToActualCameraFOV fun(self: CameraFOV): nil

_G.CAMERA_FOV_MOD = {}

---@return CameraFOV
function CAMERA_FOV_MOD.GetSingleton() end
