local results = ::require("scripts/dmViewer/protectionAnalysisHintResults.nut")

class ::gui_handlers.ProtectionAnalysisHint extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/dmViewer/protectionAnalysisHint.blk"

  cursorObj = null
  hintObj   = null
  lastHintParams = null
  cursorRadius = 0

  getValueByResultCfg = {
    penetratedArmor = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc) {
        res = ::max(res, (params?[src]?[id]?.generic ?? 0.0) + (params?[src]?[id]?.cumulative ?? 0.0))
        res = ::max(res, (params?[src]?[id]?.explosion ?? 0.0))
        res = ::max(res, (params?[src]?[id]?.shatter ?? 0.0))
      }
      return res
    }
    ricochetProb = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc)
        res = ::max(res, (params?[src]?[id] ?? 0.0))
      return res
    }
    parts = function(params, id, resultCfg) {
      local res = {}
      foreach (src in resultCfg.infoSrc)
        foreach (partId, isShow in (params?[src]?[id] ?? {}))
          res[partId] <- isShow
      return res
    }
    angle = function(params, id, resultCfg) {
      return ::max((params?.angle ?? 0.0), 0.0)
    }
  }

  printValueByParam = {
    penetratedArmor = function(val) {
      if (!val)
        return ""
      return ::loc("protection_analysis/hint/armor") + ::loc("ui/colon") +
        ::colorize("activeTextColor", ::round(val)) + " " + ::loc("measureUnits/mm")
    }
    ricochetProb = function(val) {
      if (val < 0.1)
        return ""
      return ::loc("protection_analysis/hint/ricochetProb") + ::loc("ui/colon") +
        ::colorize("activeTextColor", ::round(val * 100) + ::loc("measureUnits/percent"))
    }
    parts = function(val) {
      if (::u.isEmpty(val))
        return ""
      local prefix = ::loc("ui/bullet") + " "
      local partNames = [ ::loc("protection_analysis/hint/parts/list") + ::loc("ui/colon") ]
      foreach (partId, isShow in val)
        if (isShow)
          partNames.append(prefix + ::loc("dmg_msg_short/" + partId))
      return ::g_string.implode(partNames, "\n")
    }
    angle = function(val)
    {
      return ::loc("bullet_properties/hitAngle") + ::loc("ui/colon") +
        ::colorize("activeTextColor", ::round(val)) + ::loc("measureUnits/deg")
    }
  }

  function initScreen()
  {
    cursorObj = scene.findObject("target_cursor")
    cursorObj.setUserData(this)

    hintObj = scene.findObject("dmviewer_hint")
    hintObj.setUserData(this)

    cursorRadius = cursorObj.getSize()[0] / 2
  }

  function onEventProtectionAnalysisResult(params)
  {
    update(params)
  }

  function update(params)
  {
    if (::u.isEqual(params, lastHintParams))
      return
    lastHintParams = params

    if (!::check_obj(cursorObj) || !::check_obj(hintObj))
      return

    local isShow = !::u.isEmpty(params)
    hintObj.show(isShow)

    local resultCfg = results.getResultTypeByParams(params)
    cursorObj["background-color"] = ::get_main_gui_scene().getConstantValue(resultCfg.color)

    if (!isShow)
      return

    local getValue = getValueByResultCfg
    local printValue = printValueByParam
    local title = ::colorize(resultCfg.color, ::loc(resultCfg.loc))
    local desc = ::u.map(resultCfg.params, function(id) {
      local gFunc = getValue?[id]
      local val = gFunc ? gFunc(params, id, resultCfg) : 0
      local pFunc = printValue?[id]
      return pFunc ? pFunc(val) : ""
    })
    desc = ::g_string.implode(desc, "\n")

    hintObj.findObject("dmviewer_title").setValue(title)
    hintObj.findObject("dmviewer_desc").setValue(desc)
  }

  function onTargetingCursorTimer(obj, dt)
  {
    if(!::check_obj(obj))
      return
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    obj.left = cursorPos[0] - cursorRadius
    obj.top  = cursorPos[1] - cursorRadius
  }

  function onDMViewerHintTimer(obj, dt)
  {
    ::dmViewer.placeHint(obj)
  }
}

return {
  open = function (scene) {
    if (::check_obj(scene))
      ::handlersManager.loadHandler(::gui_handlers.ProtectionAnalysisHint, { scene = scene })
  }
}
