local unitTypes = require("scripts/unit/unitTypesList.nut")

local dbgLongestUnitTooltip = class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneTplName = "gui/debugTools/dbgLongestUnitTooltips"
  unitsByType = null
  displayableUnitTypes = null
  maxUnits = null

  function getSceneTplView() {
    unitsByType = getUnits()

    displayableUnitTypes = unitTypes.types.filter(@(t) t.isAvailable()).map(@(t) {typeName = t.typeName})

    return {
      unitType = displayableUnitTypes
    }
  }

  function initScreen() {
    scene.findObject("wnd_frame").select()
    maxUnits = {}

    foreach (id in [].extend(displayableUnitTypes.map(@(t) t.typeName), ["sample_type"])) {
      local contentObj = scene.findObject(id)
      if (::check_obj(contentObj)) {
        guiScene.replaceContent(contentObj, "gui/airTooltip.blk", this)
        contentObj.show(false)
      }
    }

    scene.findObject("update_timer").setUserData(this)
  }

  function onUpdate(obj, dt) {
    local passedLastType = null
    local unitsList = []
    for (local i = 0; i < unitTypes.types.len(); i++) {
      local uType = unitTypes.types[i]
      unitsList = unitsByType?[uType.typeName] ?? []
      if (unitsList.len() != 0)
        break

      passedLastType = uType.typeName
    }

    if (unitsList.len() == 0) {
      if (passedLastType == displayableUnitTypes.top().typeName) {
        scene.findObject("update_timer").setUserData(null)
        revealFoundedUnits()
      }
      return
    }

    guiScene.performDelayed(this, function() {
      local unit = unitsList.remove(0)
      ::dlog($"DBG: Check: left {unitsByType?[unit.unitType.typeName].len() ?? 0}, {unit.unitType.typeName} -> {unit.name}") // warning disable: -forbidden-function

      checkLongestUnitTooltip(unit)
    })
  }

  function checkLongestUnitTooltip(unit) {
    guiScene.setUpdatesEnabled(false, false)
    fillUnitInfo(unit, true)
    guiScene.setUpdatesEnabled(true, true)

    if (!::check_obj(scene))
      return

    local unitInfoObj = scene.findObject("sample_type")
    local height = unitInfoObj?.getSize()[1] ?? 0
    local { typeName } = unit.unitType
    if ((maxUnits?[typeName].height ?? -1) < height) {
      maxUnits[typeName] <- { height, unit }
      fillUnitInfo(unit)
    }
  }

  getUnits = @() ::all_units.reduce(function(res, unit) {
    local { typeName } = unit.unitType
    if (unit.isVisibleInShop())
      res[typeName] <- (res?[typeName] ?? []).append(unit)
    return res
  }, {})

  function fillUnitInfo(unit, isTesting = false) {
    if (!unit || !::check_obj(scene))
      return

    local contentObj = scene.findObject(isTesting? "sample_type" : unit.unitType.typeName)
    contentObj.show(true)
    ::showAirInfo(unit, true, contentObj.findObject("air_info_tooltip"), this, {
      showLocalState = false
    })
  }

  function revealFoundedUnits() {
    showSceneBtn("sample_unit", false)
  }

  function onEventUnitModsRecount(params) {
    local { unit = null } = params
    if (!unit)
      return

    if (maxUnits?[unit.unitType.typeName].unit == unit)
      fillUnitInfo(unit)
  }
}
::gui_handlers.dbgLongestUnitTooltip <- dbgLongestUnitTooltip

::debug_open_longest_unit_tooltips <- @() ::handlersManager.loadHandler(::gui_handlers.dbgLongestUnitTooltip)
