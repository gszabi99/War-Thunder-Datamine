::debug_wnd <- function debug_wnd(blkName = null, tplParams = {}, callbacksContext = null)
{
  ::gui_start_modal_wnd(::gui_handlers.debugWndHandler, { blkName = blkName, tplParams = tplParams, callbacksContext = callbacksContext })
}

class ::gui_handlers.debugWndHandler extends ::BaseGuiHandler
{
  sceneBlkName = "gui/debugFrame.blk"
  wndType = handlerType.MODAL

  isExist = false
  blkName = null
  tplName = null
  tplParams = {}
  lastModified = -1
  checkTimer = 0.0

  callbacksContext = null

  function initScreen()
  {
    isExist = blkName ? ::is_existing_file(blkName, false) : false
    tplName = ::g_string.endsWith(blkName, ".tpl") ? ::g_string.slice(blkName, 0, -4) : null
    tplParams = tplParams || {}

    scene.findObject("debug_wnd_update").setUserData(this)
    updateWindow()
  }

  function reinitScreen(params)
  {
    local _blkName = ::getTblValue("blkName", params, blkName)
    local _tplParams = ::getTblValue("tplParams", params, tplParams)
    if (_blkName == blkName && ::u.isEqual(_tplParams, tplParams))
      return

    blkName = _blkName
    isExist = blkName ? ::is_existing_file(blkName, false) : false
    tplName = ::g_string.endsWith(blkName, ".tpl") ? ::g_string.slice(blkName, 0, -4) : null
    tplParams = _tplParams || {}

    lastModified = -1
    updateWindow()
  }

  function updateWindow()
  {
    if (!::checkObj(scene))
      return

    local obj = scene.findObject("debug_wnd_content_box")
    if (!isExist)
    {
      local txt = (blkName == null ? "No file specified." :
        ("File not found: \"" + ::colorize("userlogColoredText", blkName) + "\""))
        + "~nUsage examples:"
        + "~ndebug_wnd(\"gui/debriefing/debriefing.blk\")"
        + "~ndebug_wnd(\"gui/menuButton.tpl\", {buttonText=\"Test\"})" // warning disable: -forgot-subst
      local data = "textAreaCentered { pos:t='pw/2-w/2, ph/2-h/2' position:t='absolute' text='" + txt + "' }"
      return guiScene.replaceContentFromText(obj, data, data.len(), callbacksContext)
    }

    if (tplName)
    {
      local data = ::handyman.render(::load_template_text(tplName), tplParams)
      guiScene.replaceContentFromText(obj, data, data.len(), callbacksContext)
    }
    else
      guiScene.replaceContent(obj, blkName, callbacksContext)

    if ("onCreate" in callbacksContext)
      callbacksContext.onCreate(obj)
  }

  function checkModify()
  {
    if (!isExist)
      return
    local modified = ::get_file_modify_time_sec(blkName)
    if (modified < 0)
      return

    if (lastModified < 0)
    {
      lastModified = modified
      return
    }

    if (lastModified != modified)
    {
      lastModified = modified
      updateWindow()
    }
  }

  function onUpdate(obj, dt)
  {
    checkTimer -= dt
    if (checkTimer < 0)
    {
      checkTimer += 0.5
      checkModify()
    }
  }
}
