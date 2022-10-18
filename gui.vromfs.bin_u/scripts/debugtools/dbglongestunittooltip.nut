from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { register_command } = require("console")

local dbgLongestUnitTooltip = class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/debugTools/dbgLongestUnitTooltips"
  unitsByType = null
  displayableUnitTypes = null
  maxUnits = null

  function getSceneTplView() {
    this.unitsByType = this.getUnits()

    this.displayableUnitTypes = unitTypes.types.filter(@(t) t.isAvailable()).map(@(t) {typeName = t.typeName})

    return {
      unitType = this.displayableUnitTypes
    }
  }

  function initScreen() {
    this.scene.findObject("wnd_frame").select()
    this.maxUnits = {}

    foreach (id in [].extend(this.displayableUnitTypes.map(@(t) t.typeName), ["sample_type"])) {
      let contentObj = this.scene.findObject(id)
      if (checkObj(contentObj)) {
        this.guiScene.replaceContent(contentObj, "%gui/airTooltip.blk", this)
        contentObj.show(false)
      }
    }

    this.scene.findObject("update_timer").setUserData(this)
  }

  function onUpdate(_obj, _dt) {
    local passedLastType = null
    local unitsList = []
    for (local i = 0; i < unitTypes.types.len(); i++) {
      let uType = unitTypes.types[i]
      unitsList = this.unitsByType?[uType.typeName] ?? []
      if (unitsList.len() != 0)
        break

      passedLastType = uType.typeName
    }

    if (unitsList.len() == 0) {
      if (passedLastType == this.displayableUnitTypes.top().typeName) {
        this.scene.findObject("update_timer").setUserData(null)
        this.revealFoundedUnits()
      }
      return
    }

    this.guiScene.performDelayed(this, function() {
      let unit = unitsList.remove(0)
      dlog($"DBG: Check: left {this.unitsByType?[unit.unitType.typeName].len() ?? 0}, {unit.unitType.typeName} -> {unit.name}") // warning disable: -forbidden-function

      this.checkLongestUnitTooltip(unit)
    })
  }

  function checkLongestUnitTooltip(unit) {
    this.guiScene.setUpdatesEnabled(false, false)
    this.fillUnitInfo(unit, true)
    this.guiScene.setUpdatesEnabled(true, true)

    if (!checkObj(this.scene))
      return

    let unitInfoObj = this.scene.findObject("sample_type")
    let height = unitInfoObj?.getSize()[1] ?? 0
    let { typeName } = unit.unitType
    if ((this.maxUnits?[typeName].height ?? -1) < height) {
      this.maxUnits[typeName] <- { height, unit }
      this.fillUnitInfo(unit)
    }
  }

  getUnits = @() ::all_units.reduce(function(res, unit) {
    let { typeName } = unit.unitType
    if (unit.isVisibleInShop())
      res[typeName] <- (res?[typeName] ?? []).append(unit)
    return res
  }, {})

  function fillUnitInfo(unit, isTesting = false) {
    if (!unit || !checkObj(this.scene))
      return

    let contentObj = this.scene.findObject(isTesting? "sample_type" : unit.unitType.typeName)
    contentObj.show(true)
    ::showAirInfo(unit, true, contentObj.findObject("air_info_tooltip"), this, {
      showLocalState = false
    })
  }

  function revealFoundedUnits() {
    this.showSceneBtn("sample_unit", false)
  }

  function onEventUnitModsRecount(params) {
    let { unit = null } = params
    if (!unit)
      return

    if (this.maxUnits?[unit.unitType.typeName].unit == unit)
      this.fillUnitInfo(unit)
  }
}
::gui_handlers.dbgLongestUnitTooltip <- dbgLongestUnitTooltip

let function debug_open_longest_unit_tooltips() {
  ::handlersManager.loadHandler(::gui_handlers.dbgLongestUnitTooltip)
}

register_command(debug_open_longest_unit_tooltips, "debug.open_longest_unit_tooltips")
