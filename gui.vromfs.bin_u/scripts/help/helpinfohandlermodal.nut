//wndInfoConfig = {
//  textsBlk - blk with texts for this window
//  links = [
//    {
//      obj     - object (or object id) to view (required)
                  //invisible object dont be highlighted, and linked messages to them will be hidden.
//      msgId   - message id in scene textsBlk to link with this object (optional)
//      highlight = true    - need especially highlight this object or not (optional default = true)
//    }
//  ]
//}

class ::gui_handlers.HelpInfoHandlerModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/tutorials/tutorWnd.blk"

  config = null
  ownerScene = null

  objContainer = null

  static function open(wndInfoConfig, wndScene)
  {
    if (!wndInfoConfig)
      return

    local params = {
      config = wndInfoConfig
      ownerScene = wndScene
    }
    return ::handlersManager.loadHandler(::gui_handlers.HelpInfoHandlerModal, params)
  }

  function initScreen()
  {
    if (!config)
      return goBack()

    objContainer = ::getTblValue("objContainer", config, ownerScene)
    if (!checkObj(objContainer))
      return goBack()

    local links = ::getTblValue("links", config)
    if (!links)
      return goBack()

    local textsBlk = config?.textsBlk
    if (textsBlk)
      guiScene.replaceContent(scene.findObject("texts_screen"), textsBlk, null)

    //update messages visibility to correct update other messages positions
    local highlightList = []
    foreach(idx, link in links)
    {
      local objBlock = ::guiTutor.getBlockFromObjData(link.obj, objContainer)

      if (!link?.msgId)
        link.msgId <- null

      local msgObj = link.msgId ? scene.findObject(link.msgId) : null
      if (::check_obj(msgObj))
      {
        msgObj.show(!!objBlock)
        if ("text" in link)
          msgObj.setValue(link.text)
      }

      if (objBlock && (link?.highlight ?? true))
        highlightList.append(objBlock.__merge({id = "lightObj_" + idx}))
    }

    guiScene.setUpdatesEnabled(true, true) //need to recount sizes and positions

    ::guiTutor.createHighlight(scene.findObject("dark_screen"), highlightList, this, { onClick = "goBack" })

    local linesData = ::LinesGenerator.getLinkLinesMarkup(getLinesGeneratorConfig())
    guiScene.replaceContentFromText(scene.findObject("lines_block"), linesData, linesData.len(), this)
  }

  getLinesGeneratorConfig = @() {
    startObjContainer = scene
    endObjContainer = objContainer
    lineInterval = config?.lineInterval
    links = ::u.keysReplace(config.links, { msgId = "start", obj = "end" })
  }

  function consoleNext()
  {
    goBack()
  }
}