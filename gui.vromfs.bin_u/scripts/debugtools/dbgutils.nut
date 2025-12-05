

from "%scripts/dagui_natives.nut" import periodic_task_register, copy_to_clipboard, update_objects_under_windows_state, get_exe_dir, periodic_task_unregister, reload_main_script_module
from "%scripts/dagui_library.nut" import *

let { setGameLocalization, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")
let { getLocalLanguage } = require("language")
let { reload } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock  = require("DataBlock")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { getVideoResolution } = require("%scripts/options/systemOptions.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let debugWnd = require("%scripts/debugTools/debugWnd.nut")
let animBg = require("%scripts/loading/animBg.nut")
let { register_command } = require("console")
let { getAllTips } = require("%scripts/loading/loadingTips.nut")
let { multiplyDaguiColorStr } = require("%sqDagui/daguiUtil.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")

function reload_dagui() {
  get_cur_gui_scene()?.resetGamepadMouseTarget()
  let res = reload(reload_main_script_module)
  update_objects_under_windows_state(get_cur_gui_scene())
  dlog("Dagui reloaded")
  return res
}

function debug_change_language(isNext = true) {
  let list = getGameLocalizationInfo()
  let curLang = getLocalLanguage()
  let curIdx = list.findindex(@(l) l.id == curLang) ?? 0
  let newIdx = curIdx + (isNext ? 1 : -1 + list.len())
  let newLang = list[newIdx % list.len()]
  setGameLocalization(newLang.id, true, false)
  dlog($"Set language: {newLang.id}")
}

function debug_change_resolution(shouldIncrease = true) {
  let curResolution = getSystemConfigOption("video/resolution")
  let list = getVideoResolution(curResolution, false)
  let curIdx = list.indexof(curResolution) ?? 0
  let newIdx = clamp(curIdx + (shouldIncrease ? 1 : -1), 0, list.len() - 1)
  let newResolution = list[newIdx]
  let done = @() dlog($"Set resolution: {newResolution}",
    "(", screen_width(), "x", screen_height(), ")")
  if (newResolution == curResolution)
    return done()
  setSystemConfigOption("video/resolution", newResolution)
  applyRendererSettingsChange(true, false, function() {
    done()
  })
}

function debug_multiply_color(colorStr, multiplier) {
  let res = multiplyDaguiColorStr(colorStr, multiplier)
  copy_to_clipboard(res)
  return res
}

function to_pixels_float(value) {
  return to_pixels($"({value}) * 1000000") / 1000000.0
}

function debug_check_dirty_words(path = null) {
  let blk = DataBlock()
  blk.load(path ?? "debugDirtyWords.blk")
  dirtyWordsFilter.setDebugLogFunc(log)
  local failed = 0
  for (local i = 0; i < blk.paramCount(); i++) {
    let text = blk.getParamValue(i)
    let filteredText = dirtyWordsFilter.checkPhrase(text)
    if (text == filteredText) {
      log($"DIRTYWORDS: PASSED {text}")
      failed++
    }
  }
  dirtyWordsFilter.setDebugLogFunc(null)
  dlog("DIRTYWORDS: FINISHED, checked", blk.paramCount(), ", failed check", failed)
}

function debug_tips_list() {
  debugWnd("%gui/debugTools/dbgTipsList.tpl",
    { tipsList = getAllTips().map(@(value) { value = value }) })
}

function debug_get_skyquake_path() {
  let dir = get_exe_dir()
  let idx = dir.indexof("/skyquake/")
  return idx != null ? dir.slice(0, idx + 9) : ""
}

let dbgFocusData = persist("dbgFocusData", @() { debugFocusTask = -1, prevSelObj = null })
function debug_focus(needShow = true) {
  if (!needShow) {
    if (dbgFocusData.debugFocusTask != -1)
      periodic_task_unregister(dbgFocusData.debugFocusTask)
    dbgFocusData.debugFocusTask = -1
    return "Switch off debug focus"
  }

  if (dbgFocusData.debugFocusTask == -1)
    dbgFocusData.debugFocusTask = periodic_task_register({},
      function(_) {
        let newObj = get_cur_gui_scene().getSelectedObject()
        let { prevSelObj } = dbgFocusData
        let isSame = newObj == prevSelObj
          || (newObj != null && (prevSelObj?.isValid() ?? true) && newObj.isEqual(prevSelObj))
        if (isSame)
          return
        let text = $"Cur focused object = {newObj?.tag} / {newObj?.id}"
        dlog(text)
        console_print(text)
        dbgFocusData.prevSelObj = newObj
      },
      1)

  dbgFocusData.prevSelObj = get_cur_gui_scene().getSelectedObject()
  let { prevSelObj } = dbgFocusData
  let text = $"Cur focused object = {prevSelObj?.tag} / {prevSelObj?.id}"
  dlog(text)
  return text
}

if (dbgFocusData.debugFocusTask != -1) {
  dbgFocusData.debugFocusTask = -1
  dbgFocusData.prevSelObj = null
  debug_focus()
}

let debug_open_url = @() openEditBoxDialog({
  title = "Enter url"
  allowEmpty = false
  okFunc = openUrl
})

register_command(reload_dagui, "debug.reload_dagui")
register_command(@() debug_change_language(), "debug.change_language_to_next")
register_command(@() debug_change_language(false), "debug.change_language_to_prev")
register_command(@() debug_change_resolution(), "debug.change_resolution_to_next")
register_command(@() debug_change_resolution(false), "debug.change_resolution_to_prev")
register_command(debug_multiply_color, "debug.multiply_color")
register_command(@(value) dlog(to_pixels(value)), "debug.to_pixels")
register_command(@(value) dlog(to_pixels_float(value)), "debug.to_pixels_float")
register_command(debug_check_dirty_words, "debug.check_dirty_words")
register_command(@(text) dirtyWordsFilter.debugDirtyWordsFilter(text, false, console_print), "debug.dirty_words_filter.phrase")
register_command(@(text) dirtyWordsFilter.debugDirtyWordsFilter(text, true,  console_print), "debug.dirty_words_filter.name")
register_command(debug_tips_list, "debug.tips_list")
register_command(animBg.debugLoad, "debug.load_anim_bg")
register_command(debug_focus, "debug.focus")
register_command(debug_open_url, "debug.open_url")
register_command(function() {
  getAllUnits().each(@(unit) unit.modificators = null)
}, "debug.remove_unit_modificators")


return {
  debug_get_skyquake_path
  debug_open_url
  reload_dagui
}