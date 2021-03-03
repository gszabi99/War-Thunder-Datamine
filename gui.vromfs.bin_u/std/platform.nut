local { dgs_get_settings } = require("dagor.system")
local { get_platform_string_id } = require("platform")
local platformId = dgs_get_settings().getStr("platform", get_platform_string_id())

local isXboxOne = platformId == "xboxOne"
local isXboxScarlett = platformId == "xboxScarlett"
local isXbox = isXboxOne || isXboxScarlett

local isPS4 = platformId == "ps4"
local isPS5 = platformId == "ps5"
local isSony = isPS4 || isPS5

local isPC = ["win32", "win64", "macosx", "linux64"].contains(platformId)

return {
  platformId
  isXboxOne
  isXboxScarlett
  isXbox
  isPS4
  isPS5
  isSony
  isPC
}