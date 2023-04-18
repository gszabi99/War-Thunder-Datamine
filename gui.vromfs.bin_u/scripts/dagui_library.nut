//checked for plus_string
//checked for explicitness
#no-root-fallback
#explicit-this

let { kwarg, memoize } = require("%sqstd/functools.nut")
let { Computed, Watched } = require("frp")
let log = require("%globalScripts/logs.nut")
let mkWatched = require("%globalScripts/mkWatched.nut")
let { loc } = require("dagor.localize")
let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")
let utf8 = require("utf8")
let isInArray = @(v, arr) arr.contains(v)
let { Callback } = require("%sqStdLibs/helpers/callback.nut")
let { hasFeature } = require("%scripts/user/features.nut")
let { platformId }  = require("%sqstd/platform.nut")

let checkObj = @(obj) obj != null && obj?.isValid()

let getTblValue = @(key, tbl, defValue = null) key in tbl ? tbl[key] : defValue

let function colorize(color, text) {
  if (color == "" || text == "")
    return text

  let firstSymbol = color.slice(0, 1)
  let prefix = (firstSymbol == "@" || firstSymbol == "#") ? "" : "@"
  return "".concat("<color=", prefix, color, ">", text, "</color>")
}

let function to_pixels(value) {
  return ::g_dagui_utils.toPixels(::get_cur_gui_scene(), value)
}

let is_platform_pc = ["win32", "win64", "macosx", "linux64"].contains(platformId)
let is_platform_windows = ["win32", "win64"].contains(platformId)
let is_platform_android = platformId == "android"
let is_platform_xbox = platformId == "xboxOne" || platformId == "xboxScarlett"

return log.__merge({
  platformId
  is_platform_pc
  is_platform_windows
  is_platform_android
  is_platform_xbox
  isInArray
  getTblValue
  checkObj
  Callback
  colorize
  to_pixels
  hasFeature

  debugTableData
  toString
  utf8
  loc
  //frp
  Watched
  Computed
  mkWatched

  //function tools
  kwarg
  memoize
})


