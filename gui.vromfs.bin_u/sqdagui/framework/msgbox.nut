#explicit-this
#no-root-fallback

let { format } = require("string")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { get_time_msec } = require("dagor.time")
let broadcastEvent = require("%sqStdLibs/helpers/subscriptions.nut").broadcast
let { stripTags } =  require("%sqstd/string.nut")

::scene_msg_boxes_list <- [] //FIX ME need to make it part of handler manager

//  {id, text, buttons, defBtn}
::gui_scene_boxes <- []

::remove_scene_box <- function remove_scene_box(id) {
  for (local i = 0; i < ::gui_scene_boxes.len(); i++) {
    if (::gui_scene_boxes[i].id == id) {
      ::gui_scene_boxes.remove(i)
      return
    }
  }
}

::destroyMsgBox <- function destroyMsgBox(boxObj) {
  if (!check_obj(boxObj))
    return
  local guiScene = boxObj.getScene()
  guiScene.destroyElement(boxObj)
  broadcastEvent("ModalWndDestroy")
}

let function clear_msg_boxes_list() {
  for (local i = ::scene_msg_boxes_list.len() - 1; i >= 0; i--)
    if (!check_obj(::scene_msg_boxes_list[i]))
      ::scene_msg_boxes_list.remove(i)
}

let function get_text_urls_data(text) {
  if (!text.len())
    return null

  let urls = []
  local start = 0
  let startText = "<url="
  let urlEndText = ">"
  let endText = "</url>"
  do {
    start = text.indexof(startText, start)
    if (start == null)
      break
    let urlEnd = text.indexof(urlEndText, start + startText.len())
    if (!urlEnd)
      break
    let end = text.indexof(endText, urlEnd)
    if (!end)
      break

    urls.append({
      url = text.slice(start + startText.len(), urlEnd)
      text = text.slice(urlEnd + urlEndText.len(), end)
    })
    text = "".concat(text.slice(0, start), text.slice(end + endText.len()))
  } while (start != null && start < text.len())

  if (!urls.len())
    return null
  return { text, urls }
}

::saved_scene_msg_box <- null  //msgBox which must be shown even when scene changed
::scene_msg_box <- function scene_msg_box(id, gui_scene, text, buttons, def_btn, options = null) {
  gui_scene = gui_scene || ::get_cur_gui_scene()
  if (options?.checkDuplicateId && check_obj(gui_scene[id]))
    return null

  local rootNode = options?.root ?? ""
  local needWaitAnim = options?.waitAnim ?? false
  local data_below_text = options?.data_below_text
  let data_below_buttons = options?.data_below_buttons
  let debug_string = options?.debug_string
  let delayedButtons = options?.delayedButtons ?? 0
  let baseHandler = options?.baseHandler
  let needAnim = ::need_new_msg_box_anim()

  local cancel_fn = options?.cancel_fn
  let needCancelFn = options?.need_cancel_fn
  if (!cancel_fn && buttons && buttons.len() == 1)
    cancel_fn = buttons[0].len() >= 2 ? buttons[0][1] : function() {}

  if (options?.saved)
    ::saved_scene_msg_box = (@(id, gui_scene, text, buttons, def_btn, options) function() {
        ::scene_msg_box(id, gui_scene, text, buttons, def_btn, options)
      })(id, gui_scene, text, buttons, def_btn, options)

  let bottomLinks = get_text_urls_data(text)
  if (bottomLinks) {
    text = bottomLinks.text
    data_below_text = data_below_text || ""
    foreach (idx, urlData in bottomLinks.urls)
      data_below_text += format("button { id:t='msgLink%d'; text:t='%s'; link:t='%s'; on_click:t = '::open_url_by_obj'; underline{} }",
                           idx, stripTags(urlData.text), stripTags(urlData.url))
  }

  if (!check_obj(gui_scene[rootNode])) {
    rootNode = ""
    if (!check_obj(gui_scene.getRoot()))
      return null
  }
  let msgbox = gui_scene.loadModal(rootNode, "%gui/msgBox.blk", needAnim ? "massTransp" : "div", null)
  if (!msgbox)
    return null
  msgbox.id = id
  println($"GuiManager: load msgbox = {id}")
//  ::enableHangarControls(false, false) //to disable hangar controls need restore them on destroy msgBox

  let textObj = msgbox.findObject("msgText")
  if (options?.font == "fontNormal")
    textObj.mediumFont = "no"
  textObj.setValue(text)

  local handlerObj = null
  if (buttons) {
    let handlerClass = class {
      function onButtonId(id) {
        if (this.startingDialogNow)
          return

        if (this.showButtonsTimer > 0)
          return

        let srcHandlerObj = this.sourceHandlerObj
        let bId = this.boxId
        let bObj = this.boxObj

        let delayedAction = function() {
          if (check_obj(this.boxObj))
            foreach (b in buttons) {
              local isDestroy = true
              if (b.len() > 2)
                isDestroy = b[2]
              if (b[0] == id || (b[0] == "" && id == "cancel")) {
                if (b.len() > 1 && b[1])
                  b[1].call(srcHandlerObj)

                if (isDestroy) {
                  ::remove_scene_box(bId) //!!FIX ME: need refactoring about this list
                  ::saved_scene_msg_box = null
                  ::destroyMsgBox(bObj)
                  clear_msg_boxes_list()
                }
                break
              }
            }
          this.startingDialogNow = false;
        }
        this.startingDialogNow = true;
        this.guiScene.performDelayed(this, delayedAction)
      }

      function onButton(obj) {
        this.onButtonId(obj.id)
      }

      function onAccessKey(obj) {
        this.onButtonId(obj.id.slice(3))
      }

      function onAcceptSelectionAccessKey(_obj) {
        if (this.showButtonsTimer > 0)
          return
        let btnObj = check_obj(this.boxObj) ? this.boxObj.findObject("buttons_holder") : null
        if (!check_obj(btnObj) || !btnObj.isVisible())
          return
        let total = btnObj.childrenCount()
        let value = btnObj.getValue()
        if (value < 0 || value >= total)
          return
        local button = btnObj.getChild(value)
        for (local i = 0; i < total; i++) {
          let bObj = btnObj.getChild(i)
          if (bObj?.isValid() && bObj.isHovered())
            button = bObj
        }
        if (button?.isValid() && button.isEnabled())
          return this.onButtonId(button.id)
      }

      function onUpdate(_obj, dt) {
        ::reset_msg_box_check_anim_time()
        // If buttons need
        if (this.showButtonsTimer > 0) {
          this.showButtonsTimer -= dt
          if (this.showButtonsTimer <= 0) {
            if (check_obj(this.boxObj)) {
              let btnObj = this.boxObj.findObject("buttons_holder")
              if (check_obj(btnObj)) {
                btnObj.show(true)
                btnObj.enable(true)
                btnObj.select()
              }
            }
          }
        }

        if (this.need_cancel_fn && this.need_cancel_fn()) {
          this.need_cancel_fn = null;
          this.onButtonId("");
        }
      }

      sourceHandlerObj = null
      guiScene = null
      boxId = null
      boxObj = null
      showButtonsTimer = -1
      startingDialogNow = false
      need_cancel_fn = null
    }

    handlerObj = handlerClass()
    handlerObj.guiScene = gui_scene

    if (buttons) {
      local blkText = ""
      local navText = @"Button_text
            {
              id:t = 'ak_select_btn';
              btnName:t='A';
              on_click:t = 'onAcceptSelectionAccessKey'
              text:t = '#mainmenu/btnSelect';
              display:t='none'
              ButtonImg {}
            }"

      if (cancel_fn) {
        local alreadyHave = false
        foreach (b in buttons)
          if (b[0] == "")
            alreadyHave = true
        if (!alreadyHave)
          buttons.append(["", cancel_fn])
      }

      local defBtnIdx = 0
      local idx = -1
      let animParams = needAnim ? "color-factor:t='0';" : ""
      foreach (btn in buttons) {
        if (btn[0] != "") {
          let locTxtId = (btn[0].slice(0, 1) == "#") ? btn[0] : $"#msgbox/btn_{btn[0]}"
          local btnText = "".concat("text:t='", locTxtId, "'; id:t='", btn[0], "'; on_click:t='onButton';")
          if (buttons.len() == 1)
            btnText = "".concat(btnText, "btnName:t='AB'; ") //Enter and Esc for the single button
          blkText = "".concat(blkText, "Button_text { ", animParams, btnText, "}")
          idx++
          if (btn[0] == def_btn)
            defBtnIdx = idx
        }
        if (btn[0] == "cancel" || btn[0] == "") {
          navText = "".concat(navText, @"Button_text
            {
              id:t = 'ak_cancel';
              text:t = '#msgbox/btn_cancel';
              btnName:t='B';
              on_click:t = 'onAccessKey'
              display:t='none'
              ButtonImg {}
            }")
        }
      }

      if (navText.len() > 0)
        navText = "".concat("navRight { ", navText, " }")

      handlerObj.sourceHandlerObj = baseHandler
      handlerObj.boxId = msgbox.id
      handlerObj.boxObj = msgbox
      handlerObj.need_cancel_fn = needCancelFn

      let holderObj = msgbox.findObject("buttons_holder")
      if (holderObj != null) {
        gui_scene.appendWithBlk(holderObj, blkText, handlerObj)

        if (delayedButtons > 0) {
          holderObj.show(false)
          holderObj.enable(false)
          handlerObj.showButtonsTimer = delayedButtons
        }
        else
          holderObj.setValue(defBtnIdx)
      }

      let navObj = msgbox.findObject("msg-nav-bar")
      if (navObj != null)
        gui_scene.appendWithBlk(navObj, navText, handlerObj)
    }
  }
  if (!buttons)
    needWaitAnim = true  //if no buttons, than wait anim always need

  if (needWaitAnim) {
    let waitObj = msgbox.findObject("msgWaitAnimation")
    if (waitObj)
      waitObj.show(true)
  }

  if (data_below_text) {
    let containerObj = msgbox.findObject("msg_div_after_text")
    if (containerObj) {
      gui_scene.replaceContentFromText(containerObj, data_below_text, data_below_text.len(), baseHandler || handlerObj)
      containerObj.show(true)
    }
  }
  if (data_below_buttons) {
    let containerObj = msgbox.findObject("msg_bottom_div")
    if (containerObj) {
      gui_scene.replaceContentFromText(containerObj, data_below_buttons, data_below_buttons.len(), baseHandler)
      containerObj.show(true)
    }
  }

  let containerObj = msgbox.findObject("msgTextRoot")
  if (check_obj(containerObj)) {
    gui_scene.applyPendingChanges(false)
    let isNeedVCentering = containerObj.getSize()[1] < containerObj.getParent().getSize()[1]
    containerObj["pos"] = isNeedVCentering ? "0, ph/2-h/2" : "0, 0"
  }

  if (debug_string) {
    let obj = msgbox.findObject("msg_debug_string")
    if (obj) {
      obj.setValue(debug_string)
      obj.show(true)
    }
  }

  if (delayedButtons == 0)
    msgbox.findObject("buttons_holder")?.select()

  ::scene_msg_boxes_list.append(msgbox)
  broadcastEvent("MsgBoxCreated")
  return msgbox
}

local last_scene_msg_box_time = -1

::reset_msg_box_check_anim_time <- function reset_msg_box_check_anim_time() {
  last_scene_msg_box_time = get_time_msec()
}

::need_new_msg_box_anim <- function need_new_msg_box_anim() {
  return get_time_msec() - last_scene_msg_box_time > 200
}


::destroy_all_msg_boxes <- function destroy_all_msg_boxes(guiScene = null) {
  for (local i = ::scene_msg_boxes_list.len() - 1; i >= 0; i--) {
    let msgBoxObj = ::scene_msg_boxes_list[i]
    if (check_obj(msgBoxObj)) {
      let objGuiScene = msgBoxObj.getScene()
      if (guiScene && !guiScene.isEqual(objGuiScene))
        continue

      objGuiScene.destroyElement(msgBoxObj)
    }
    ::scene_msg_boxes_list.remove(i)
  }
}

::is_active_msg_box_in_scene <- function is_active_msg_box_in_scene(guiScene) {
  foreach (msgBoxObj in ::scene_msg_boxes_list)
   if (check_obj(msgBoxObj) && guiScene.isEqual(msgBoxObj.getScene()))
     return true
  return false
}

::update_msg_boxes <- function update_msg_boxes() {
  let guiScene = ::get_gui_scene()
  if (guiScene == null)
    return

  if (guiScene["wait_box_tag"] != null)
    return

  local msgsToShow = []

  for (local i = 0; i < ::gui_scene_boxes.len(); i++) {
    let msg = ::gui_scene_boxes[i]
    if (msg.id == "signin_change") {
      msgsToShow = []
      msgsToShow.append(i)
      break
    }
    else
      msgsToShow.append(i)
  }

  for (local i = 0; i < msgsToShow.len(); i++) {
    let msg = ::gui_scene_boxes[msgsToShow[i]]
    let options = msg?.options
    if (guiScene[msg.id] == null)
      ::scene_msg_box(msg.id, guiScene, msg.text, msg.buttons, msg.defBtn, options)
  }
}

::add_msg_box <- function add_msg_box(id, text, buttons, def_btn, options = null) {
  for (local i = 0; i < ::gui_scene_boxes.len(); i++) {
    if (::gui_scene_boxes[i].id == id) {
      ::update_msg_boxes()
      return
    }
  }

  let mb = {}
  mb.id <- id
  mb.text <- text
  mb.buttons <- buttons
  mb.defBtn <- def_btn
  mb.options <- options
  ::gui_scene_boxes.append(mb)
  ::update_msg_boxes()
}

::showInfoMsgBox <- function showInfoMsgBox(text, id = "info_msg_box", checkDuplicateId = false) {
  ::scene_msg_box(id, null, text, [["ok", function() {} ]], "ok",
                  { cancel_fn = function() {}, checkDuplicateId = checkDuplicateId })
}