//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")


let results = require("%scripts/dmViewer/protectionAnalysisHintResults.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { round } = require("math")

let { set_protection_analysis_editing } = require("hangarEventCommand")

gui_handlers.ProtectionAnalysisHint <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/dmViewer/protectionAnalysisHint.blk"

  cursorObj = null
  hintObj   = null
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
      return loc("protection_analysis/hint/armor") + loc("ui/colon") +
        colorize("activeTextColor", round(val)) + " " + loc("measureUnits/mm")
    }
    ricochetProb = function(val) {
      if (val < 0.1)
        return ""
      return loc("protection_analysis/hint/ricochetProb") + loc("ui/colon") +
        colorize("activeTextColor", round(val * 100) + loc("measureUnits/percent"))
    }
    parts = function(val) {
      if (u.isEmpty(val))
        return ""
      let prefix = loc("ui/bullet") + " "
      let partNames = [ loc("protection_analysis/hint/parts/list") + loc("ui/colon") ]
      foreach (partId, isShow in val)
        if (isShow)
          partNames.append(prefix + loc("dmg_msg_short/" + partId))
      return "\n".join(partNames, true)
    }
    angle = function(val) {
      return loc("bullet_properties/hitAngle") + loc("ui/colon") +
        colorize("activeTextColor", round(val)) + loc("measureUnits/deg")
    }
    headingAngle = function(val) {
      return loc("protection_analysis/hint/headingAngle") + loc("ui/colon") +
        colorize("activeTextColor", round(val)) + loc("measureUnits/deg")
    }
  }

  function initScreen() {
    this.cursorObj = this.scene.findObject("target_cursor")
    this.cursorObj.setUserData(this)

    this.hintObj = this.scene.findObject("dmviewer_hint")
    this.hintObj.setUserData(this)

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
    local desc = resultCfg.params.map(function(id) {
      let gFunc = getValue?[id]
      let val = gFunc ? gFunc(params, id, resultCfg) : 0
      let pFunc = printValue?[id]
      return pFunc ? pFunc(val) : ""
    })
    desc = "\n".join(desc, true)

    this.hintObj.findObject("dmviewer_title").setValue(title)
    this.hintObj.findObject("dmviewer_desc").setValue(desc)
  }

  function onTargetingCursorTimer(obj, _dt) {
    if (!checkObj(obj))
      return
    let cursorPos = get_dagui_mouse_cursor_pos_RC()
    obj.left = cursorPos[0] - this.cursorRadius
    obj.top  = cursorPos[1] - this.cursorRadius
  }

  function onDMViewerHintTimer(obj, _dt) {
    ::dmViewer.placeHint(obj)
  }
}

return {
  open = function (scene) {
    if (checkObj(scene))
      handlersManager.loadHandler(gui_handlers.ProtectionAnalysisHint, { scene = scene })
  }
}
