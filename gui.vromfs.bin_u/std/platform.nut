local {dgs_get_settings} = require("dagor.system")
local platform = require("platform")
local {get_platform_string_id, get_console_model} = platform

local platformId = dgs_get_settings().getStr("platform", get_platform_string_id())
local oneOf = @(...) vargv.contains(platformId)
local consoleModel = get_console_model()
local isModel = @(model) consoleModel == model

local is_pc = oneOf("win32", "win64", "macosx", "linux64")
local is_sony = oneOf("ps4", "ps5")
local is_xbox = oneOf("xboxOne", "xboxScarlett")
local is_nswitch = oneOf("nswitch")
local is_mobile = oneOf("iOS", "android")
local is_console = is_sony || is_xbox || is_nswitch
local isXboxOne = platformId == "xboxOne"
local isXboxScarlett = platformId == "xboxScarlett"
local isXbox = isXboxOne || isXboxScarlett

local isPS4 = platformId == "ps4"
local isPS5 = platformId == "ps5"
local isSony = isPS4 || isPS5

local isPC = ["win32", "win64", "macosx", "linux64"].contains(platformId)

local aliases = {
  pc = is_pc
  xbox = is_xbox
  sony = is_sony
  console = is_console
  mobile = is_mobile
}
local platformAlias = is_sony ? "sony"
  : is_xbox ? "xbox"
  : is_mobile ? "mobile"
  : is_pc ? "pc"
  : platformId

enum SCE_REGION {
  SCEE = "scee"
  SCEA = "scea"
  SCEJ = "scej"
}

return {
  platformId
  platformAlias
  is_pc
  is_windows = oneOf("win32", "win64")
  is_ps4 = oneOf("ps4")
  is_ps5 = oneOf("ps5")
  is_sony
  is_android = oneOf("android")
  is_ios = oneOf("iOS")
  is_mobile
  is_xbox
  is_xboxone = oneOf("xboxOne")
  is_xbox_scarlett = oneOf("xboxScarlett")
  is_nswitch
  is_xboxone_simple = isModel(platform.XBOXONE)
  is_xboxone_s = isModel(platform.XBOXONE_S)
  is_xboxone_X = isModel(platform.XBOXONE_X)
  is_xbox_lockhart = isModel(platform.XBOX_LOCKHART)
  is_xbox_anaconda = isModel(platform.XBOX_ANACONDA)
  is_ps4_simple = oneOf("ps4") && isModel(platform.PS4)
  is_ps4_pro = oneOf("ps4") && isModel(platform.PS4_PRO)
  is_console
  aliases
  SCE_REGION

  isXboxOne
  isXboxScarlett
  isXbox
  isPS4
  isPS5
  isSony
  isPC
}