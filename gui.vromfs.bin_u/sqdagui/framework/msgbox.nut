::scene_msg_boxes_list <- [] //FIX ME need to make it part of handler manager

//  {id, text, buttons, defBtn}
::gui_scene_boxes <- []
local g_string =  require("std/string.nut")

::remove_scene_box <- function remove_scene_box(id)
{
  for (local i = 0; i < ::gui_scene_boxes.len(); i++)
  {
    if (::gui_scene_boxes[i].id == id)
    {
      ::gui_scene_boxes.remove(i)
      return
    }
  }
}

::remove_all_scene_boxes <- function remove_all_scene_boxes()
{
  ::gui_scene_boxes = []
}

::destroyMsgBox <- function destroyMsgBox(boxObj)
{
  if(!::check_obj(boxObj))
    return
  local guiScene = boxObj.getScene()
  guiScene.destroyElement(boxObj)
  ::broadcastEvent("ModalWndDestroy")
}

::saved_scene_msg_box <- null  //msgBox which must be shown even when scene changed
::scene_msg_box <- function scene_msg_box(id, gui_scene, text, buttons, def_btn, options = null)
{
  gui_scene = gui_scene || ::get_cur_gui_scene()
  if (options?.checkDuplicateId && ::check_obj(gui_scene[id]))
    return null

  local rootNode = options?.root ?? ""
  local needWaitAnim = options?.waitAnim ?? false
  local data_below_text = options?.data_below_text
  local data_below_buttons = options?.data_below_buttons
  local debug_string = options?.debug_string
  local delayedButtons = options?.delayedButtons ?? 0
  local baseHandler = options?.baseHandler
  local needAnim = ::need_new_msg_box_anim()

  local cancel_fn = options?.cancel_fn
  local needCancelFn = options?.need_cancel_fn
  if (!cancel_fn && buttons && buttons.len() == 1)
    cancel_fn = buttons[0].len() >= 2 ? buttons[0][1] : function(){}

  if (options?.saved)
    ::saved_scene_msg_box = (@(id, gui_scene, text, buttons, def_btn, options) function() {
        scene_msg_box(id, gui_scene, text, buttons, def_btn, options)
      })(id, gui_scene, text, buttons, def_btn, options)

  local bottomLinks = get_text_urls_data(text)
  if (bottomLinks)
  {
    text = bottomLinks.text
    data_below_text = data_below_text || ""
    foreach(idx, urlData in bottomLinks.urls)
      data_below_text += ::format("button { id:t='msgLink%d'; text:t='%s'; link:t='%s'; on_click:t = '::open_url_by_obj'; underline{} }",
                           idx, g_string.stripTags(urlData.text), g_string.stripTags(urlData.url))
  }

  if (!::check_obj(gui_scene[rootNode]))
  {
    rootNode = ""
    if (!::check_obj(gui_scene.getRoot()))
      return null
  }
  local msgbox = gui_scene.loadModal(rootNode, "gui/msgBox.blk", needAnim ? "massTransp" : "div", null)
  if (!msgbox)
    return null
  msgbox.id = id
  ::dagor.debug("GuiManager: load msgbox = " + id)
//  ::enableHangarControls(false, false) //to disable hangar controls need restore them on destroy msgBox

  local textObj = msgbox.findObject("msgText")
  if (options?.font == "fontNormal")
    textObj.mediumFont = "no"
  textObj.setValue(text)

  local handlerObj = null
  if (buttons)
  {
    local handlerClass = class {
      function onButtonId(id)
      {
        if (startingDialogNow)
          return

        if (showButtonsTimer>0)
          return

        local srcHandlerObj = sourceHandlerObj
        local bId = boxId
        local bObj = boxObj

        local delayedAction = function() {
          if (::check_obj(boxObj))
            foreach (b in buttons)
            {
              local isDestroy = true
              if (b.len() > 2)
                isDestroy = b[2]
              if (b[0] == id || (b[0]=="" && id == "cancel"))
              {
                if (isDestroy)
                {
                  ::remove_scene_box(bId) //!!FIX ME: need refactoring about this list
                  ::saved_scene_msg_box = null
                  ::destroyMsgBox(bObj)
                  ::clear_msg_boxes_list()
                }
                if (b.len()>1 && b[1])
                  b[1].call(srcHandlerObj)
                break
              }
            }
          startingDialogNow = false;
        }
        startingDialogNow = true;
        guiScene.performDelayed(this, delayedAction)
      }

      function onButton(obj)
      {
        onButtonId(obj.id)
      }

      function onAccessKey(obj)
      {
        onButtonId(obj.id.slice(3))
      }

      function onUpdate(obj, dt)
      {
        ::reset_msg_box_check_anim_time()
        if (showButtonsTimer>0)
        {
          showButtonsTimer -= dt
          if (showButtonsTimer<=0)
          {
            if (::check_obj(boxObj))
            {
              local btnObj = boxObj.findObject("buttons_holder")
              if (::check_obj(btnObj))
              {
                btnObj.show(true)
                btnObj.enable(true)
                if (::check_obj(defBtn))
                  defBtn.select()
              }
            }
          }
        }

        if (need_cancel_fn && need_cancel_fn())
        {
          need_cancel_fn = null;
          onButtonId("");
        }
      }

      sourceHandlerObj = null
      guiScene = null
      boxId = null
      boxObj = null
      showButtonsTimer = -1
      defBtn = null
      startingDialogNow = false
      need_cancel_fn = null
    }

    local blkText = ""
    local navText = @"Button_text
          {
            id:t = 'ak_select_btn';
            btnName:t='A';
            text:t = '#mainmenu/btnSelect';
            display:t='none'
            ButtonImg {}
          }"

    if (cancel_fn)
    {
      local alreadyHave = false
      foreach(b in buttons)
        if (b[0]=="")
          alreadyHave =true
      if (!alreadyHave)
        buttons.append(["", cancel_fn])
    }

    local animParams = needAnim ? "color-factor:t='0';" : ""
    foreach (btn in buttons)
    {
      if (btn[0]!="")
      {
        local locTxtId = (btn[0].slice(0,1) == "#") ? btn[0] : "#msgbox/btn_" + btn[0]
        local btnText = "text:t='" + locTxtId + "'; id:t='" + btn[0] + "'; on_click:t='onButton';"
        if (buttons.len() == 1)
          btnText += "btnName:t='AB'; " //Enter and Esc for the single button
        blkText += "Button_text { " + animParams + btnText + "}"
      }
      if (btn[0] == "cancel" || btn[0] == "")
      {
        navText += @"Button_text
          {
            id:t = 'ak_cancel';
            text:t = '#msgbox/btn_cancel';
            btnName:t='B';
            on_click:t = 'onAccessKey'
            display:t='none'
            ButtonImg {}
          }"
      }
    }

    if (navText.len() > 0)
      navText = "navRight { " + navText + " }"

    handlerObj = handlerClass()
    handlerObj.sourceHandlerObj = baseHandler
    handlerObj.guiScene = gui_scene
    handlerObj.boxId = msgbox.id
    handlerObj.boxObj = msgbox
    handlerObj.need_cancel_fn = needCancelFn

    local holderObj = msgbox.findObject("buttons_holder")
    if (holderObj != null)
    {
      gui_scene.appendWithBlk(holderObj, blkText, handlerObj)
      if (def_btn != null && def_btn.len() > 0)
      {
        local defBtnObj = msgbox.findObject(def_btn)
        if (defBtnObj != null)
        {
          defBtnObj.select()
          handlerObj.defBtn = defBtnObj
        }
      }

      if (delayedButtons>0)
      {
        msgbox.findObject("msg_box_timer").setUserData(handlerObj)
        holderObj.show(false)
        holderObj.enable(false)
        handlerObj.showButtonsTimer = delayedButtons
      }
    }

    local navObj = msgbox.findObject("msg-nav-bar")
    if (navObj != null)
      gui_scene.appendWithBlk(navObj, navText, handlerObj)

//    local navBar = gui_scene["nav-help"]
//    if (navBar != null)
//      navBar.display = "none"
  } else
    needWaitAnim = true  //if no buttons, than wait anim always need

  if (needWaitAnim)
  {
    local waitObj = msgbox.findObject("msgWaitAnimation")
    if (waitObj)
      waitObj.show(true)
  }

  if (data_below_text)
  {
    local containerObj = msgbox.findObject("msg_div_after_text")
    if (containerObj)
    {
      gui_scene.replaceContentFromText(containerObj, data_below_text, data_below_text.len(), baseHandler || handlerObj)
      containerObj.show(true)
    }
  }
  if (data_below_buttons)
  {
    local containerObj = msgbox.findObject("msg_bottom_div")
    if (containerObj)
    {
      gui_scene.replaceContentFromText(containerObj, data_below_buttons, data_below_buttons.len(), baseHandler)
      containerObj.show(true)
    }
  }

  local containerObj = msgbox.findObject("msgTextRoot")
  if (::check_obj(containerObj))
  {
    gui_scene.applyPendingChanges(false)
    local isNeedVCentering = containerObj.getSize()[1] < containerObj.getParent().getSize()[1]
    containerObj["pos"] = isNeedVCentering ? "0, ph/2-h/2" : "0, 0"
  }

  if (debug_string)
  {
    local obj = msgbox.findObject("msg_debug_string")
    if (obj)
    {
      obj.setValue(debug_string)
      obj.show(true)
    }
  }

  ::scene_msg_boxes_list.append(msgbox)
  ::broadcastEvent("MsgBoxCreated")
  return msgbox
}

::last_scene_msg_box_time <- -1
::reset_msg_box_check_anim_time <- function reset_msg_box_check_anim_time()
{
  ::last_scene_msg_box_time = ::dagor.getCurTime()
}
::need_new_msg_box_anim <- function need_new_msg_box_anim()
{
  return ::dagor.getCurTime() - ::last_scene_msg_box_time > 200
}

::clear_msg_boxes_list <- function clear_msg_boxes_list()
{
  for(local i = ::scene_msg_boxes_list.len()-1; i >= 0; i--)
    if (!::check_obj(::scene_msg_boxes_list[i]))
      ::scene_msg_boxes_list.remove(i)
}

::destroy_all_msg_boxes <- function destroy_all_msg_boxes(guiScene = null)
{
  for(local i = ::scene_msg_boxes_list.len()-1; i >= 0; i--)
  {
    local msgBoxObj = ::scene_msg_boxes_list[i]
    if (::check_obj(msgBoxObj))
    {
      local objGuiScene = msgBoxObj.getScene()
      if (guiScene && !guiScene.isEqual(objGuiScene))
        continue

      objGuiScene.destroyElement(msgBoxObj)
    }
    ::scene_msg_boxes_list.remove(i)
  }
}

::is_active_msg_box_in_scene <- function is_active_msg_box_in_scene(guiScene)
{
  foreach(msgBoxObj in ::scene_msg_boxes_list)
   if (::check_obj(msgBoxObj) && guiScene.isEqual(msgBoxObj.getScene()))
     return true
  return false
}

::update_msg_boxes <- function update_msg_boxes()
{
  local guiScene = ::get_gui_scene()
  if (guiScene == null)
    return

  if (guiScene["wait_box_tag"] != null)
    return

  local msgsToShow = []

  for (local i = 0; i < ::gui_scene_boxes.len(); i++)
  {
    local msg = ::gui_scene_boxes[i]
    if (msg.id == "signin_change")
    {
      msgsToShow = []
      msgsToShow.append(i)
      break
    }
    else
      msgsToShow.append(i)
  }

  for (local i = 0; i < msgsToShow.len(); i++)
  {
    local msg = ::gui_scene_boxes[msgsToShow[i]]
    local options = msg?.options
    if (guiScene[msg.id] == null)
      scene_msg_box(msg.id, guiScene, msg.text, msg.buttons, msg.defBtn, options)
  }
}

::get_text_urls_data <- function get_text_urls_data(text)
{
  if (!text.len() || !::has_feature("AllowExternalLink"))
    return null

  local urls = []
  local start = 0
  local startText = "<url="
  local urlEndText = ">"
  local endText = "</url>"
  do {
    start = text.indexof(startText, start)
    if (start == null)
      break
    local urlEnd = text.indexof(urlEndText, start + startText.len())
    if (!urlEnd)
      break
    local end = text.indexof(endText, urlEnd)
    if (!end)
      break

    urls.append({
      url = text.slice(start + startText.len(), urlEnd)
      text = text.slice(urlEnd + urlEndText.len(), end)
    })
    text = text.slice(0, start) + text.slice(end + endText.len())
  } while (start != null && start < text.len())

  if (!urls.len())
    return null
  return { text = text, urls = urls }
}

::add_msg_box <- function add_msg_box(id, text, buttons, def_btn, options = null)
{
  for (local i = 0; i < ::gui_scene_boxes.len(); i++)
  {
    if (::gui_scene_boxes[i].id == id)
    {
      ::update_msg_boxes()
      return
    }
  }

  local mb = {}
  mb.id <- id
  mb.text <- text
  mb.buttons <- buttons
  mb.defBtn <- def_btn
  mb.options <- options
  ::gui_scene_boxes.append(mb)
  ::update_msg_boxes()
}

::showInfoMsgBox <- function showInfoMsgBox(text, id = "info_msg_box", checkDuplicateId = false)
{
  ::scene_msg_box(id, null, text, [["ok", function() {} ]], "ok",
                  { cancel_fn = function() {}, checkDuplicateId = checkDuplicateId})
}