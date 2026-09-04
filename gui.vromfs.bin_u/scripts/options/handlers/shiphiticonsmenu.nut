from "%globalScripts/shipHitIconsConsts.nut" import ShipHitIconId, SHIP_HIT_ICONS_VIS_ALL_FLAGS
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "guiOptions" import get_gui_option

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { MultiSelectMenu } = require("%scripts/wndLib/multiSelectMenu.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_option, get_option, registerOption, def_set_gui_option, mkUseroptHardWatched } = require("%scripts/options/optionsExt.nut")
let { USEROPT_SHOW_HIT_ICONS_SHIP } = require("%scripts/options/optionsExtNames.nut")
let { ShipHitIconVisibilityMask, ShipHitIconCfgId } = require("%globalScripts/shipHitIconsConsts.nut")
let { get_available_ship_hit_notifications } = require("%scripts/options/optionsStorage.nut")

let ShipHitIcons = {
  [ShipHitIconId.HIT]                = "ui/gameuiskin#dm_ship_armor_hit.svg",
  [ShipHitIconId.HIT_EFFECTIVE]      = "ui/gameuiskin#dm_ship_armor_breach.svg",
  [ShipHitIconId.HIT_INEFFECTIVE]    = "ui/gameuiskin#dm_ship_armor_unbroken.svg",
  [ShipHitIconId.HIT_PIERCE_THROUGH] = "ui/gameuiskin#dm_ship_armor_breach_through.svg",
  [ShipHitIconId.HIT_CREW]           = "ui/gameuiskin#dm_ship_crew.svg"
}

let optionsList = persist("shipHitIconsOptionsList", @() [])

function initOptionsList() {
  let hitIconsIds = [ ShipHitIconId.HIT, ShipHitIconId.HIT_EFFECTIVE, ShipHitIconId.HIT_CREW,
    ShipHitIconId.HIT_INEFFECTIVE, ShipHitIconId.HIT_PIERCE_THROUGH ]
  let availableIcons = get_available_ship_hit_notifications()

  let opts = hitIconsIds.map(function(iconId) {
    let cfgId = ShipHitIconCfgId[iconId]
    let tooltipLocKey = $"shipHitHint/{cfgId}/tooltip"
    let tooltip = doesLocTextExist(tooltipLocKey)
      ? $"#{tooltipLocKey}"
      : ""
    return {
      value = ShipHitIconVisibilityMask[iconId]
      isHiddenOpt = cfgId not in availableIcons
      enable = true
      text = $"#shipHitHint/{cfgId}"
      tooltip
      icon = ShipHitIcons[iconId]
    }
  })

  optionsList.replace(opts)
}

class ShipHitIconsMenu (MultiSelectMenu) {
  align = ALIGN.TOP

  getSceneTplView = @() {
    value = get_option(USEROPT_SHOW_HIT_ICONS_SHIP).value
    list = this.list
  }

  getStateFlags = @(vals) vals.reduce(@(sf, val) sf | val, 0)
  onFinalApplyCb = @(v) set_option(USEROPT_SHOW_HIT_ICONS_SHIP, this.getStateFlags(v))

  function initScreen() {
    base.initScreen()
    let curValue = this.scene.findObject("multi_select").getValue()
    this.initialBitMask = curValue
    this.currentBitMask = curValue
  }
}

register_gui_handler("ShipHitIconsMenu", ShipHitIconsMenu)

function openShipHitIconsMenu(alignObj) {
  handlersManager.loadHandler(ShipHitIconsMenu, { alignObj, list = optionsList })
}

let iconsVisibilitySf = mkUseroptHardWatched("shipHitIconsVisibilityStateFlags", SHIP_HIT_ICONS_VIS_ALL_FLAGS)  
function setUseroptShiptHitIconsVisibility(value, descr, optionId) {
  value = value ?? SHIP_HIT_ICONS_VIS_ALL_FLAGS
  iconsVisibilitySf.set(value)
  def_set_gui_option(value, descr, optionId)
}

function filllUseroptShiptHitIconsVisibility(optionId, descr, _context) {
  descr.id = "shipHitIconsSettings"
  descr.controlType = optionControlType.BUTTON
  descr.funcName <- "onShipHitIconsVisibilityClick"
  descr.text <- loc("mainmenu/btnShowShipHitIcons")
  descr.value = get_gui_option(optionId) ?? SHIP_HIT_ICONS_VIS_ALL_FLAGS
}

registerOption(USEROPT_SHOW_HIT_ICONS_SHIP, filllUseroptShiptHitIconsVisibility, setUseroptShiptHitIconsVisibility)

addListenersWithoutEnv({
  function InitConfigs(_) {
    iconsVisibilitySf.set(get_option(USEROPT_SHOW_HIT_ICONS_SHIP).value)
    initOptionsList()
  }
})

return { openShipHitIconsMenu }
