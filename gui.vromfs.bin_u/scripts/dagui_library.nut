from "math" import min, max, clamp

require("%sqstd/globalState.nut").setUniqueNestKey("dagui")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { kwarg, memoize } = require("%sqstd/functools.nut")
let { Computed, Watched, WatchedRo } = require("%sqstd/frp.nut")
let log = require("%globalScripts/logs.nut")
let mkWatched = require("%globalScripts/mkWatched.nut")
let { loc } = require("dagor.localize")
let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")
let utf8 = require("utf8")
let isInArray = @(v, arr) arr.contains(v)
let { Callback } = require("%sqStdLibs/helpers/callback.nut")
let { hasFeature } = require("%scripts/user/features.nut")
let { toPixels, showObjById, showObjectsByTable, ALIGN } = require("%sqDagui/daguiUtil.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let nativeApi = require("%sqDagui/daguiNativeApi.nut")
let checkObj = @(obj) obj != null && obj?.isValid()
let { scene_msg_box, destroyMsgBox, showInfoMsgBox } = require("%sqDagui/framework/msgBox.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isStringFloat } = require("%sqstd/string.nut")
let sharedEnums = require("%globalScripts/sharedEnums.nut")

let getTblValue = @(key, tbl, defValue = null) key in tbl ? tbl[key] : defValue

function colorize(color, text) {
  if (color == "" || text == "")
    return text

  let firstSymbol = color.slice(0, 1)
  let prefix = (firstSymbol == "@" || firstSymbol == "#") ? "" : "@"
  return "".concat("<color=", prefix, color, ">", text, "</color>")
}
let get_cur_gui_scene = nativeApi.get_cur_gui_scene
function to_pixels(value) {
  return toPixels(get_cur_gui_scene(), value)
}

let getAircraftByName = @(name) getAllUnits()?[name]

function is_numeric(value) {
  let t = type(value)
  return t == "integer" || t == "float" || t == "int64"
}

function to_integer_safe(value, defValue = 0, needAssert = true) {
  if (!is_numeric(value) && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_int_safe", $"can't convert '{value}' to integer")
    return defValue
  }
  return value.tointeger()
}

function to_float_safe(value, defValue = 0, needAssert = true) {
  if (!is_numeric(value)
    && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_float_safe", $"can't convert '{value}' to float")
    return defValue
  }
  return value.tofloat()
}

let get_roman_numeral_lookup = [
  "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
  "", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC",
  "", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM",
]
const MAX_ROMAN_DIGIT = 3



function get_roman_numeral(num) { 
  if (!is_numeric(num) || num < 0) {
    script_net_assert_once("get_roman_numeral", $"get_roman_numeral({num})")
    return ""
  }

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  let thousands = []
  for (local n = 0; n < num / 1000; n++)
    thousands.append("M")

  local roman = []
  local i = -1
  while (num > 0 && i++ < MAX_ROMAN_DIGIT) {
    let digit = num % 10
    num = num / 10
    roman = [getTblValue(digit + (i * 10), get_roman_numeral_lookup, "")].extend(roman)
  }
  return "".join(thousands.extend(roman))
}

let registeredFunctions = {}
function registerForNativeCall(name, func){
 let root = getroottable()
 assert(name not in registeredFunctions, @() $"'{name}' already registered")
 registeredFunctions[name] <- true
 root[name] <- func
}

return log.__merge(nativeApi, sharedEnums, {
  min
  max
  clamp
  is_numeric
  to_integer_safe
  to_float_safe
  get_roman_numeral
  registerForNativeCall

  nbsp = " " 
  destroyMsgBox
  showInfoMsgBox
  scene_msg_box

  isInArray
  getTblValue
  checkObj
  showObjById
  showObjectsByTable
  Callback
  colorize
  to_pixels
  hasFeature

  debugTableData
  toString
  utf8
  loc
  
  Watched
  Computed
  mkWatched
  WatchedRo

  
  kwarg
  memoize

  
  getAircraftByName

  ALIGN
})


