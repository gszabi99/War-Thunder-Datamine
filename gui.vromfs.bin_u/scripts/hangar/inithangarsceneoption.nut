from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_HANGAR_SCENE
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let hangarScenes = require("%appGlobals/config/hangarScenes.nut")
let { selectedHangar } = require("%scripts/hangar/initHangar.nut")
let { registerOption } = require("%scripts/options/optionsExt.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")
let { get_settings_blk } = require("blkGetters")
let { getTimestampFromStringUtc, calculateCorrectTimePeriodYears } = require("%scripts/time.nut")
let { get_charserver_time_sec } = require("chard")

const DEFAULT_VALUE = "hangar_default"

let getCustomHangar = @() get_settings_blk()?.hangarBlk

let getRegularHangarPath = @(_id = null) getCustomHangar() ?? "config/hangar.blk"

let hangarSceneOptionList = [{ id = DEFAULT_VALUE }, { id = "hangar_regular", getPath = getRegularHangarPath }]
  .extend(hangarScenes.filter(@(v) v?.isVisibleInOption ?? true))

let getHangarPathById = @(id) $"config/{id}.blk"

function calculateCurDefaultHangar(updFunc) {
  let customHangar = getCustomHangar()
  if (customHangar != null)
    return customHangar
  let currentTime = get_charserver_time_sec()
  local nextChangeTime = null
  local curHangar = null
  foreach (hangarSceneParams in hangarScenes) {
    let { id, beginDate = null, endDate = null, customPath = null, getPath = getHangarPathById } = hangarSceneParams
    if (beginDate == null || endDate == null)
      continue

    let { startTime, endTime } = calculateCorrectTimePeriodYears(
      getTimestampFromStringUtc(beginDate), getTimestampFromStringUtc(endDate))
    if (currentTime >= endTime)
      continue

    let nextTime = startTime > currentTime ? startTime : endTime
    nextChangeTime = min(nextChangeTime ?? nextTime, nextTime)
    if (startTime < currentTime)
      curHangar = customPath ?? getPath(id)
  }
  if (nextChangeTime != null)
    setTimeout(nextChangeTime - currentTime, updFunc)
  return curHangar ?? getRegularHangarPath()
}

let getHangarSceneOptionValue = @() get_gui_option_in_mode(USEROPT_HANGAR_SCENE, OPTIONS_MODE_GAMEPLAY, DEFAULT_VALUE)

function updateSelectedHangar() {
  if (!hasFeature("HangarSceneOption")) {
    selectedHangar.set("")
    return
  }
  let self = callee()
  clearTimer(self)
  let hangarId = getHangarSceneOptionValue()
  let hangarSceneParams = hangarSceneOptionList.findvalue(@(v) v.id == hangarId)
    ?? hangarSceneOptionList.findvalue(@(v) v.id == DEFAULT_VALUE)
  if (hangarSceneParams == null) {
    selectedHangar.set("")
    return
  }
  let { id, customPath = null, getPath = getHangarPathById } = hangarSceneParams
  let path = id == DEFAULT_VALUE ? calculateCurDefaultHangar(self)
    : (customPath ?? getPath(id))
  selectedHangar.set(path)
}

isProfileReceived.subscribe(@(v) v ? updateSelectedHangar() : null)
if (isProfileReceived.get())
  updateSelectedHangar()

function fillHangarSceneOptionDescr(_optionId, descr, _context) {
  descr.id = "hangar_scene"
  descr.defaultValue = DEFAULT_VALUE
  descr.items = []
  descr.values = []
  let curValue = getHangarSceneOptionValue()
  foreach (idx, hangar in hangarSceneOptionList) {
    let { id, locId = null } = hangar
    descr.items.append(loc(locId ?? $"options/{id}"))
    descr.values.append(id)
    if (curValue == id)
      descr.value = idx
  }
}

function setHangarSceneOption(value, descr, optionId) {
  let hangarId = descr.values?[value] ?? DEFAULT_VALUE
  if (hangarId == getHangarSceneOptionValue())
    return
  set_gui_option_in_mode(optionId, hangarId, OPTIONS_MODE_GAMEPLAY)
  updateSelectedHangar()
}

registerOption(USEROPT_HANGAR_SCENE, fillHangarSceneOptionDescr, setHangarSceneOption)
