from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import USEROPT_SKIN, USEROPT_USER_SKIN,
  USEROPT_INFANTRY_SKIN, USEROPT_TANK_SKIN_CONDITION, USEROPT_TANK_CAMO_SCALE,
  USEROPT_TANK_CAMO_ROTATION
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/customization/customizationConsts.nut" import TANK_CAMO_SCALE_SLIDER_FACTOR,
  TANK_CAMO_ROTATION_SLIDER_FACTOR
from "%sqstd/platform.nut" import isPC
let { registerOption } = require("%scripts/options/optionsExt.nut")
let { getSkinsOption, getCurUnitUserSkins, getUserSkinCondition,
  getUserSkinScale, getUserSkinRotation, setLastSkin
} = require("%scripts/customization/skins.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { set_gui_option } = require("guiOptions")
let { get_user_skins_profile_blk } = require("blkGetters")
let { on_user_skin_profile_changed, get_tank_skin_condition,
  get_tank_camo_scale, get_tank_camo_rotation } = require("unitCustomization")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { debug_dump_stack } = require("dagor.debug")
let { getLocationInfantrySkins, saveInfantrySkin } = require("%scripts/customization/infantryCamouflageStorage.nut")
let { convertLevelNameToLocation, getInfantrySkinTooltip } = require("%scripts/customization/infantryCamouflageUtils.nut")

function fillSkin(_optionId, descr, _context) {
  descr.id = "skin"
  descr.trParams <- "optionWidthInc:t='double';"
  let unitName = unitNameForWeapons.get() ?? ""
  if (unitName != "") {
    let skins = getSkinsOption(unitName)
    descr.items = skins.items
    descr.values = skins.values
    descr.value = skins.value
    descr.access <- skins.access
  }
  else {
    descr.items = []
    descr.values = []
  }
}

function setSkin(value, descr, optionId) {
  if (type(descr.values) == "array") {
    let unitName = unitNameForWeapons.get()
    if (value >= 0 && value < descr.values.len()) {
      let isAutoSkin = descr.access[value].isAutoSkin
      set_gui_option(optionId, descr.values[value] ?? "")
      setLastSkin(unitName, isAutoSkin ? null : descr.values[value])
    }
    else
      print($"[ERROR] value '{value}' is out of range")
  }
  else
    print($"[ERROR] No values set for type '{optionId}'")
}

registerOption(USEROPT_SKIN, fillSkin, setSkin)

function fillUserSkin(_optionId, descr, _context) {
  descr.id = "user_skins"
  descr.items = [{
                   text = "#options/disabled"
                   tooltip = "#userSkin/disabled/tooltip"
                }]
  descr.values = [""]
  descr.defaultValue = ""

  let unitName = unitNameForWeapons.get()
  assert(unitName != null, "ERROR: variable unitNameForWeapons is null")

  if (isPC && hasFeature("UserSkins") && unitName) {
    let skinsBlock = getCurUnitUserSkins()
    let cdb = get_user_skins_profile_blk()
    let setValue = cdb?[unitName]

    if (skinsBlock) {
      for (local i = 0; i < skinsBlock.blockCount(); i++) {
        let table = skinsBlock.getBlock(i)
        descr.items.append({
          text = table.name
          tooltip = "".concat(loc("userSkin/custom/desc"), " \"", colorize("userlogColoredText", table.name)
            "\"\n", loc("userSkin/custom/note"))
        })

        descr.values.append(table.name)
        if (setValue != null && setValue == table.name)
          descr.value = i + 1
      }
    }
    if (descr.value == null) {
      descr.value = 0
      if (setValue)
        cdb[unitName] = descr.defaultValue
    }
  }
}

function setUserSkin(value, descr, _optionId) {
  let cdb = get_user_skins_profile_blk()
  let unitName = unitNameForWeapons.get()
  if (unitName) {
    if (cdb?[unitName] != (descr.values?[value] ?? "")) {
      let skin = descr.values?[value] ?? ""
      cdb[unitName] = skin
      on_user_skin_profile_changed(unitName, skin)
      saveProfile()
    }
  }
  else {
    log("[ERROR] unitNameForWeapons is null")
    debug_dump_stack()
  }
}

registerOption(USEROPT_USER_SKIN, fillUserSkin, setUserSkin)

function fillTankSkinCondition(_optionId, descr, _context) {
  descr.id = "skin_condition"
  descr.controlType = optionControlType.SLIDER
  descr.min <- -100
  descr.max <- 100
  descr.step <- 1
  descr.defVal <- getUserSkinCondition() ?? 0
  descr.value = get_tank_skin_condition().tointeger()
  descr.optionCb = "onChangeTankSkinCondition"
  descr.needCommonCallback = false
}

registerOption(USEROPT_TANK_SKIN_CONDITION, fillTankSkinCondition)

function fillTankCamoScale(_optionId, descr, _context) {
  descr.id = "camo_scale"
  descr.controlType = optionControlType.SLIDER
  descr.min <- (-100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
  descr.max <- (100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
  descr.step <- 1
  descr.defVal <- getUserSkinScale() ?? 0
  descr.value = (get_tank_camo_scale() * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
  descr.optionCb = "onChangeTankCamoScale"
  descr.needCommonCallback = false
}

registerOption(USEROPT_TANK_CAMO_SCALE, fillTankCamoScale)

function fillTankCamoRotation(_optionId, descr, _context) {
  descr.id = "camo_rotation"
  descr.controlType = optionControlType.SLIDER
  descr.min <- (-100 * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
  descr.max <- (100 * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
  descr.step <- 1
  descr.defVal <- getUserSkinRotation() ?? 0
  descr.value = (get_tank_camo_rotation() * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
  descr.optionCb = "onChangeTankCamoRotation"
  descr.needCommonCallback = false
}

registerOption(USEROPT_TANK_CAMO_ROTATION, fillTankCamoRotation)

function fillInfantrySkin(_optionId, descr, context) {
  descr.id = "infantry_skin"
  descr.trParams <- "optionWidthInc:t='double';"
  let locationName = convertLevelNameToLocation(context.level)
  let skins = getLocationInfantrySkins(locationName, context.team, context.tier)
  descr.items = []
  descr.values = []
  descr.location <- locationName
  descr.team <- context.team
  descr.tier <- context.tier
  foreach (skin in skins) {
    descr.items.append({
      text = skin
      tooltip = getInfantrySkinTooltip(skin)
    })
    descr.values.append(skin)
  }
}

function setInfantrySkin(value, descr, optionId) {
  if (type(descr.values) == "array") {
    if (value >= 0 && value < descr.values.len()) {
      set_gui_option(optionId, descr.values[value] ?? "")
      saveInfantrySkin(descr.values[value] ?? "default", descr.location, descr.team, descr.tier, unitNameForWeapons.get() ?? "")
    }
    else
      print($"[ERROR] value '{value}' is out of range")
  }
  else
    print($"[ERROR] No values set for type '{optionId}'")
}

registerOption(USEROPT_INFANTRY_SKIN, fillInfantrySkin, setInfantrySkin)
