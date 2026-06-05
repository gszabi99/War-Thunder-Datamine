from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let results = require("%scripts/dmViewer/protectionAnalysisHintResults.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { round, sqrt, atan2, PI } = require("math")

let { set_protection_analysis_editing } = require("hangarEventCommand")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let dmViewer = require("%scripts/dmViewer/dmViewer.nut")

gui_handlers.ProtectionAnalysisHint <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/dmViewer/protectionAnalysisHint.blk"

  cursorObj = null
  hintObj   = null
  sightLineObj = null
  lastHintParams = null
  cursorRadius = 0

  getValueByResultCfg = {
    penetratedArmor = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc) {
        res = max(res, (params?[src]?[id]?.generic ?? 0.0) +
          (params?[src]?[id]?.genericLongRod ?? 0.0) +
          (params?[src]?[id]?.explosiveFormedProjectile ?? 0.0) +
          (params?[src]?[id]?.cumulative ?? 0.0))
        res = max(res, (params?[src]?[id]?.explosion ?? 0.0))
        res = max(res, (params?[src]?[id]?.shatter ?? 0.0))
      }
      return res
    }
    ricochetProb = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc)
        res = max(res, (params?[src]?[id] ?? 0.0))
      return res
    }
    parts = function(params, id, resultCfg) {
      let res = {}
      foreach (src in resultCfg.infoSrc)
        foreach (partId, isShow in (params?[src]?[id] ?? {}))
          res[partId] <- isShow
      return res
    }
    angle = function(params, _id, _resultCfg) {
      return max((params?.angle ?? 0.0), 0.0)
    }
    headingAngle = function(params, _id, _resultCfg) {
      return max((params?.headingAngle ?? 0.0), 0.0)
    }
  }

  printValueByParam = {
    penetratedArmor = function(val) {
      if (!val)
        return ""
      return "".concat(loc("protection_analysis/hint/armor"), loc("ui/colon"),
        colorize("activeTextColor", round(val)), loc("measureUnits/mm"))
    }
    ricochetProb = function(val) {
      if (val < 0.1)
        return ""
      return "".concat(loc("protection_analysis/hint/ricochetProb"), loc("ui/colon"),
        colorize("activeTextColor", round(val * 100)), loc("measureUnits/percent"))
    }
    parts = function(val) {
      if (u.isEmpty(val))
        return ""
      let prefix = "".concat(loc("ui/bullet"), " ")
      let partNames = [ "".concat(loc("protection_analysis/hint/parts/list"), loc("ui/colon")) ]
      foreach (partId, isShow in val)
        if (isShow)
          partNames.append("".concat(prefix, loc($"dmg_msg_short/{partId}")))
      return "\n".join(partNames, true)
    }
    angle = function(val) {
      return "".concat(loc("bullet_properties/hitAngle"), loc("ui/colon"),
        colorize("activeTextColor", round(val)), loc("measureUnits/deg"))
    }
    headingAngle = function(val) {
      return "".concat(loc("protection_analysis/hint/headingAngle"), loc("ui/colon"),
        colorize("activeTextColor", round(val)), loc("measureUnits/deg"))
    }
  }

  function initScreen() {
    this.cursorObj = this.scene.findObject("target_cursor")
    this.cursorObj.setUserData(this)

    this.hintObj = this.scene.findObject("dmviewer_hint")
    this.hintObj.setUserData(this)

    this.sightLineObj = this.scene.findObject("torpedo_sight_line")
    this.cursorRadius = this.cursorObj.getSize()[0] / 2
  }

  function onEventProtectionAnalysisResult(params) {
    this.update(params)
  }

  function getCursorIsActive() {
    return this.isValid() && this.scene.isHovered()
  }

  function update(params) {
    let isCursorActive = this.getCursorIsActive()
    set_protection_analysis_editing(!isCursorActive)

    if (u.isEqual(params, this.lastHintParams))
      return
    this.lastHintParams = params

    if (!checkObj(this.cursorObj) || !checkObj(this.hintObj))
      return

    let isShow = isCursorActive && !u.isEmpty(params)
    this.hintObj.show(isShow)

    let resultCfg = results.getResultTypeByParams(params)
    this.cursorObj["background-color"] = isCursorActive
      ? get_main_gui_scene().getConstantValue(resultCfg.color)
      : "#00000000"

    if (!isShow)
      return

    let getValue = this.getValueByResultCfg
    let printValue = this.printValueByParam
    let title = colorize(resultCfg.color, loc(resultCfg.loc))
    let needAngle = params?.needAngle ?? true
    local desc = resultCfg.params
      .filter(@(id) needAngle || id != "angle")
      .map(function(id) {
        let gFunc = getValue?[id]
        let val = gFunc ? gFunc(params, id, resultCfg) : 0
        let pFunc = printValue?[id]
        return pFunc ? pFunc(val) : ""
      })

    this.hintObj.findObject("dmviewer_title").setValue(title)
    let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items = desc.map(@(v) { value = v }) })
    this.guiScene.replaceContentFromText(this.hintObj.findObject("dmviewer_desc"), data, data.len(), this)
  }

  function onTargetingCursorTimer(obj, _dt) {
    if (!checkObj(obj))
      return
    let cursorPos = get_dagui_mouse_cursor_pos_RC()
    obj.left = cursorPos[0] - this.cursorRadius
    obj.top  = cursorPos[1] - this.cursorRadius

    if (!checkObj(this.sightLineObj))
      return
    let p = this.lastHintParams
    let active = this.getCursorIsActive() && p?.sightX0 != null
    if (!active) {
      this.sightLineObj.show(false)
      return
    }
    let dx = p.sightX1 - p.sightX0
    let dy = p.sightY1 - p.sightY0
    let length = sqrt(dx * dx + dy * dy)
    if (length < 1) {
      this.sightLineObj.show(false)
      return
    }
    let thickness = 2
    let cx = (p.sightX0 + p.sightX1) * 0.5
    let cy = (p.sightY0 + p.sightY1) * 0.5
    this.sightLineObj.width = length.tointeger()
    this.sightLineObj.height = thickness
    this.sightLineObj.left = (cx - length * 0.5).tointeger()
    this.sightLineObj.top = (cy - thickness * 0.5).tointeger()
    this.sightLineObj.rotation = (atan2(dy, dx) * 180.0 / PI).tointeger()
    this.sightLineObj.show(true)
  }

  function onDMViewerHintTimer(obj, _dt) {
    dmViewer.placeHint(obj)
  }
}

return {
  open = @(scene) !checkObj(scene) ? null
    : handlersManager.loadHandler(gui_handlers.ProtectionAnalysisHint, { scene })
}
