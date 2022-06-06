let { format } = require("string")
let time = require("%scripts/time.nut")
let ingame_chat = require("%scripts/chat/mpChatModel.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { isChatEnabled, isChatEnableWithPlayer } = require("%scripts/chat/chatStates.nut")
let { is_replay_playing } = require("replays")

::game_chat_handler <- null

::get_game_chat_handler <- function get_game_chat_handler()
{
  if (!::game_chat_handler)
    ::game_chat_handler = ::ChatHandler()
  return ::game_chat_handler
}

enum mpChatView {
  CHAT
  BATTLE
}

const CHAT_WINDOW_APPEAR_TIME = 0.125
const CHAT_WINDOW_VISIBLE_TIME = 10.0
const CHAT_WINDOW_DISAPPEAR_TIME = 3.0

local MP_CHAT_PARAMS = {
  selfHideInput = false     // Hide input on send/cancel
  hiddenInput = false       // Chat is read-only
  selfHideLog = false       // Hide log on timer
  isInSpectateMode = false  // is player in spectate mode
}

::ChatHandler <- class
{
  maxLogSize = 20
  log_text = ""
  curMode = ::g_mp_chat_mode.TEAM

  senderColor = "@chatSenderFriendColor"
  senderEnemyColor = "@chatSenderEnemyColor"
  senderMeColor = "@chatSenderMeColor"
  senderMySquadColor = "@chatSenderMySquadColor"
  senderSpectatorColor = "@chatSenderSpectatorColor"

  blockedColor = "@chatTextBlockedColor"

  voiceTeamColor = "@chatTextTeamVoiceColor"
  voiceSquadColor = "@chatTextSquadVoiceColor"
  voiceEnemyColor = "@chatTextEnemyVoiceColor"

  scenes = [] //{ idx, scene, handler, transparency, selfHideInput, selfHideLog }
  last_scene_idx = 0
  sceneIdxPID = ::dagui_propid.add_name_id("sceneIdx")

  isMouseCursorVisible = false
  isActive = false // While it is true, in-game unit control shortcuts are disabled in client.
  visibleTime = 0
  chatInputText = ""
  modeInited = false
  hasEnableChatMode = false

  constructor()
  {
    ::g_script_reloader.registerPersistentData("mpChat", this,
      ["log_text", "curMode",
       "isActive", "chatInputText"
      ])

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
    isMouseCursorVisible = ::is_cursor_visible_in_gui()
  }

  function loadScene(obj, chatBlk, handler, params = MP_CHAT_PARAMS)
  {
    if (!::checkObj(obj))
      return null

    cleanScenesList()
    let sceneData = findSceneDataByScene(obj)
    if (sceneData)
    {
      sceneData.handler = handler
      return sceneData
    }

    obj.getScene().replaceContent(obj, chatBlk, this)
    return addScene(obj, handler, params)
  }

  function addScene(newScene, handler, params)
  {
    let sceneData = MP_CHAT_PARAMS.__merge(params).__update({
      idx = ++last_scene_idx
      scene = newScene
      handler = handler
      transparency = 0.0
      curTab = mpChatView.CHAT
    })

    let sceneObjIds = [
      "chat_prompt_place",
      "chat_input",
      "chat_log",
      "chat_tabs"
    ]

    let scene = sceneData.scene

    foreach (objName in sceneObjIds)
    {
      let obj = scene.findObject(objName)
      if (obj)
        obj.setIntProp(sceneIdxPID, sceneData.idx)
    }

    let timerObj = scene.findObject("chat_update")
    if (timerObj && (sceneData?.selfHideInput || sceneData?.selfHideLog))
    {
      timerObj.setIntProp(sceneIdxPID, sceneData.idx)
      timerObj.setUserData(this)
      updateChatScene(sceneData, 0.0)
      updateChatInput(sceneData)
    }

    updateTabs(sceneData)
    updateContent(sceneData)
    updatePrompt(sceneData)
    scenes.append(sceneData)
    validateCurMode()
    ::call_darg("hudChatHasEnableChatModeUpdate", hasEnableChatMode)
    ::handlersManager.updateControlsAllowMask()
    return sceneData
  }

  function cleanScenesList()
  {
    for(local i = scenes.len() - 1; i >= 0; i--)
      if (!::checkObj(scenes[i].scene))
        scenes.remove(i)
  }

  function findSceneDataByScene(scene)
  {
    foreach(sceneData in scenes)
      if (::checkObj(sceneData.scene) && sceneData.scene.isEqual(scene))
        return sceneData
    return null
  }

  function findSceneDataByObj(obj)
  {
    let idx = obj.getIntProp(sceneIdxPID, -1)
    foreach(i, sceneData in scenes)
      if (sceneData.idx == idx)
        if (::checkObj(sceneData.scene))
          return sceneData
        else
        {
          scenes.remove(i)
          break
        }
    return null
  }

  function doForAllScenes(func)
  {
    for(local i = scenes.len() - 1; i >= 0; i--)
      if (::checkObj(scenes[i].scene))
        func(scenes[i])
      else
        scenes.remove(i)
  }

  function onUpdate(obj, dt)
  {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData)
      updateChatScene(sceneData, dt)
  }

  function updateChatScene(sceneData, dt)
  {
    if (!sceneData.selfHideLog)
      return

    let isHudVisible = ::is_hud_visible()
    local transparency = sceneData.transparency
    if (!isHudVisible)
      transparency = 0
    else if (!isActive)
    {
      if (visibleTime > 0)
        visibleTime -= dt
      else
        transparency -= dt / CHAT_WINDOW_DISAPPEAR_TIME
    }
    else
      transparency += dt / CHAT_WINDOW_APPEAR_TIME
    transparency = clamp(transparency, 0.0, 1.0)

    let transValue = (isHudVisible && isVisibleWithCursor(sceneData)) ? 100 :
      (100.0 * (3.0 - 2.0 * transparency) * transparency * transparency).tointeger()

    let obj = sceneData.scene.findObject("chat_log_tdiv")
    if (::checkObj(obj))
    {
      obj.transparent = transValue
      sceneData.scene.findObject("chat_log").transparent = transValue
    }

    sceneData.transparency = transparency
  }

  function onEventChangedCursorVisibility(params)
  {
    isMouseCursorVisible = ::is_cursor_visible_in_gui()

    doForAllScenes(function(sceneData) {
      updateTabs(sceneData)
      updateContent(sceneData)
      updateChatInput(sceneData)
      updateChatScene(sceneData, 0.0)
    })
  }

  function canEnableChatInput()
  {
    if (!isChatEnabled() || !hasEnableChatMode)
      return false
    foreach(sceneData in scenes)
      if (!sceneData.hiddenInput && ::checkObj(sceneData.scene) && sceneData.scene.isVisible())
        return true
    return false
  }

  function enableChatInput(value)
  {
    if (value == isActive)
      return

    isActive = value
    if (isActive)
      visibleTime = CHAT_WINDOW_VISIBLE_TIME

    doForAllScenes(updateChatInput)
    ::broadcastEvent("MpChatInputToggled", { active = isActive })
    ::handlersManager.updateControlsAllowMask()
  }

  function updateChatInput(sceneData)
  {
    if (isActive && !sceneData.scene.isVisible())
      return

    let show = (isActive || !sceneData.selfHideInput)
                 && !sceneData.hiddenInput
                 && isChatEnabled()
                 && getCurView(sceneData) == mpChatView.CHAT
                 && hasEnableChatMode
    let scene = sceneData.scene

    ::showBtnTable(scene, {
        chat_input_back           = show
        chat_input_placeholder    = !show && canEnableChatInput()
        show_chat_input_accesskey = !show && sceneData.isInSpectateMode
    })
    ::enableBtnTable(scene, {
        chat_input              = show
        btn_send                = show
        chat_prompt             = show && ::g_mp_chat_mode.getNextMode(curMode.id) != null
        chat_mod_accesskey      = show && (sceneData.isInSpectateMode || !::is_hud_visible)
    })
    if (show && sceneData.scene.isVisible())
    {
      let obj = scene.findObject("chat_input")
      if (::check_obj(obj))
      {
        obj.getScene().performDelayed(this, function()
        {
          if (!::check_obj(obj))
            return

          obj.setValue(chatInputText)

          if (sceneData?.isInputSelected ?? true)
            selectChatEditbox(obj)
        })
      }
    }
  }

  function selectChatEditbox(obj)
  {
    if (!::is_in_flight() || ::get_is_in_flight_menu())
      ::select_editbox(obj)
    else
      obj.select()
  }

  function hideChatInput(sceneData, value)
  {
    if (value && isActive)
      enableChatInput(false)

    sceneData.hiddenInput = value
    updateChatInput(sceneData)
  }

  function onChatIngameRequestActivate(obj = null)
  {
    ::toggle_ingame_chat(true)
  }

  function onChatIngameRequestCancel(obj = null)
  {
    ::toggle_ingame_chat(false)
  }

  function onChatIngameRequestEnter(obj)
  {
    let editboxObj = ::check_obj(obj) ? obj.getParent().findObject("chat_input") : null
    if (::check_obj(editboxObj) && editboxObj?["on_activate"] == "onChatEntered")
      onChatEntered(editboxObj)
  }

  function onChatEntered(obj)
  {
    let sceneData = findSceneDataByObj(obj)
    if (!sceneData)
      return

    if (sceneData.handler && ("onEmptyChatEntered" in sceneData.handler) && obj && obj.getValue()=="")
      sceneData.handler.onEmptyChatEntered()
    else
    {
      onChatSend()
      if (sceneData.handler && ("onChatEntered" in sceneData.handler))
        sceneData.handler.onChatEntered()
    }
    enableChatInput(false)
    ::call_darg("hudChatInputEnableUpdate", false)
  }

  function onChatCancel(obj)
  {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData && sceneData.handler && ("onChatCancel" in sceneData.handler))
      sceneData.handler.onChatCancel()
    enableChatInput(false)
    ::call_darg("hudChatInputEnableUpdate", false)
  }

  function checkAndPrintDevoiceMsg()
  {
    local devoiceMsgText = penalties.getDevoiceMessage()
    if (devoiceMsgText)
    {
      devoiceMsgText = "<color=@chatInfoColor>" + devoiceMsgText + "</color>"
      ingame_chat.onInternalMessage(devoiceMsgText)
      setInputField("")
    }
    return devoiceMsgText != null
  }

  function onChatSend()
  {
    if (checkAndPrintDevoiceMsg())
      return
    ::chat_on_send()
  }

  function onEventPlayerPenaltyStatusChanged(params)
  {
    checkAndPrintDevoiceMsg()
  }

  function onChatChanged(obj)
  {
    chatInputText = obj.getValue()
    ::chat_on_text_update(chatInputText)
  }

  function onChatWrapAttempt()
  {
    // Do nothing, just to prevent hud chat editbox from losing focus.
  }

  function onEventMpChatInputChanged(params)
  {
    setInputField(params.str)
  }

  function setInputField(str)
  {
    doForAllScenes(function(sceneData) {
      let edit = sceneData.scene.findObject("chat_input")
      if (edit)
        edit.setValue(str)
    })
  }

  function onChatTabChange(obj)
  {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData)
    {
      sceneData.curTab = obj.getValue()
      updateContent(sceneData)
      updateChatInput(sceneData)
    }
  }

  function onEventMpChatInputRequested(params)
  {
    let activate = ::getTblValue("activate", params, false)
    if (activate && canEnableChatInput())
      foreach(sceneData in scenes)
        if (getCurView(sceneData) != mpChatView.CHAT)
          if (!sceneData.hiddenInput && ::checkObj(sceneData.scene) && sceneData.scene.isVisible())
          {
            let obj = sceneData.scene.findObject("chat_tabs")
            if (::checkObj(obj))
            {
              obj.setValue(mpChatView.CHAT)
              break
            }
          }
  }

  function onEventBattleLogMessage(params)
  {
    doForAllScenes(updateBattleLog)
  }

  function updateContent(sceneData)
  {
    updateChatLog(sceneData)
    updateBattleLog(sceneData)
  }

  function updateBattleLog(sceneData)
  {
    if (getCurView(sceneData) != mpChatView.BATTLE)
      return
    let limit = (!sceneData.selfHideLog || isVisibleWithCursor(sceneData)) ? 0 : maxLogSize
    let chat_log = sceneData.scene.findObject("chat_log")
    if (::checkObj(chat_log))
      chat_log.setValue(::HudBattleLog.getText(0, limit))
  }

  function updatePrompt(sceneData)
  {
    let scene = sceneData.scene
    let prompt = scene.findObject("chat_prompt")
    if (prompt)
    {
      prompt.chatMode = curMode.name
      if (::getTblValue("no_text", prompt, "no") != "yes")
        prompt.setValue(curMode.getNameText())
      if ("tooltip" in prompt)
        prompt.tooltip = ::loc("chat/to") + ::loc("ui/colon") + curMode.getDescText()
    }

    let input = scene.findObject("chat_input")
    if (input)
      input.chatMode = curMode.name

    let hint = scene.findObject("chat_hint")
    if (hint)
      hint.setValue(getChatHint())
  }

  function getChatHint()
  {
    return ::g_mp_chat_mode.getChatHint()
  }

  function onEventMpChatModeChanged(params)
  {
    let newMode = ::g_mp_chat_mode.getModeById(params.modeId)
    if (newMode == curMode)
      return

    curMode = newMode
    doForAllScenes(updatePrompt)
  }

  function onChatMode()
  {
    let newModeId = ::g_mp_chat_mode.getNextMode(curMode.id)
    setMode(::g_mp_chat_mode.getModeById(newModeId))
  }

  function onShowChatInput()
  {
    enableChatInput(true)
  }

  function setMode(mpChatMode)
  {
    ::chat_set_mode(mpChatMode.id, "")
  }

  function validateCurMode()
  {
    if (!modeInited)
    {
      modeInited = true
      hasEnableChatMode = false
      // On mp session start mode is reset to TEAM
      if (::g_mp_chat_mode.SQUAD.isEnabled()) {
        hasEnableChatMode = true
        setMode(::g_mp_chat_mode.SQUAD)
        return
      }
    }

    if (curMode.isEnabled()) {
      hasEnableChatMode = true
      return
    }

    foreach(mode in ::g_mp_chat_mode.types)
      if (mode.isEnabled()) {
        hasEnableChatMode = true
        setMode(mode)
        return
     }
  }

  function showPlayerRClickMenu(playerName)
  {
    playerContextMenu.showMenu(null, this, {
      playerName = playerName
      isMPChat = true
      chatLog = getChatLogForBanhammer()
      canComplain = true
    })
  }

  getChatLogForBanhammer = @() ingame_chat.getLogForBanhammer()

  function onChatLinkClick(obj, itype, link)  { onChatLink(obj, link, ::is_platform_pc) }
  function onChatLinkRClick(obj, itype, link) { onChatLink(obj, link, false) }

  function onChatLink(obj, link, lclick)
  {
    let sceneData = findSceneDataByObj(obj)
    if ((link && link.len() < 4) || sceneData.hiddenInput) return

    if(link.slice(0, 3) == "PL_")
    {
      if (lclick)
      {
        if (sceneData && !sceneData?.isInSpectateMode)
          addNickToEdit(sceneData, link.slice(3))
      }
      else
        showPlayerRClickMenu(link.slice(3))
    }
    else if (::g_chat.checkBlockedLink(link))
    {
      log_text = ::g_chat.revealBlockedMsg(log_text, link)

      let pureMessage = ::g_chat.convertLinkToBlockedMsg(link)
      ingame_chat.unblockMessage(pureMessage)
      updateAllLogs()
    }
  }

  function onEventWatchedHeroSwitched(params)
  {
    makeChatTextFromLog()
  }

  function onEventMpChatLogUpdated(params)
  {
    makeChatTextFromLog()
  }

  function onEventContactsBlockStatusUpdated(params) {
    makeChatTextFromLog()
  }

  function makeChatTextFromLog()
  {
    let log = ingame_chat.getLog()
    log_text = ""
    for (local i = 0; i < log.len(); ++i)
      log_text = ::g_string.implode([log_text , makeTextFromMessage(log[i])], "\n")
    updateAllLogs()

    let autoShowOpt = ::get_option(::USEROPT_AUTO_SHOW_CHAT)
    if (autoShowOpt.value)
    {
      doForAllScenes(function(sceneData) {
        if (!sceneData.scene.isVisible())
          return

        sceneData.transparency = 1.0
        updateChatScene(sceneData, 0.0)
      })
    }
  }


  function makeTextFromMessage(message)
  {
    let timeString = time.secondsToString(message.time, false)
    if (message.sender == "") //system
      return format(
        "%s <color=@chatActiveInfoColor>%s</color>",
        timeString,
        ::loc(message.text))

    local text = message.isAutomatic
      ? message.text
      : ::g_chat.filterMessageText(message.text, message.isMyself)

    if (!message.isMyself && !message.isAutomatic)
    {
      if (::isPlayerNickInContacts(message.sender, ::EPL_BLOCKLIST))
        text = ::g_chat.makeBlockedMsg(message.text)
      else if (!isChatEnableWithPlayer(message.sender))
        text = ::g_chat.makeXBoxRestrictedMsg(message.text)
    }

    let userColor = getSenderColor(message)
    let msgColor = getMessageColor(message)
    let clanTag = ::get_player_tag(message.sender)
    let fullName = ::g_contacts.getPlayerFullName(
      platformModule.getPlayerName(message.sender),
      clanTag
    )
    message.userColor = userColor
    message.msgColor = msgColor
    message.clanTag = clanTag
    return format(
      "%s <Color=%s>[%s] <Link=PL_%s>%s:</Link></Color> <Color=%s>%s</Color>",
      timeString,
      userColor,
      ::g_mp_chat_mode.getModeById(message.mode).getNameText(),
      message.sender,
      fullName,
      msgColor,
      text
    )
  }


  function getSenderColor(message)
  {
    if (isSenderMe(message))
      return senderMeColor
    else if (::isPlayerDedicatedSpectator(message.sender))
      return senderSpectatorColor
    else if (message.team != ::get_player_army_for_hud() || !::is_mode_with_teams())
      return senderEnemyColor
    else if (isSenderInMySquad(message))
      return senderMySquadColor
    return senderColor
  }

  function getMessageColor(message)
  {
    if (message.isBlocked)
      return blockedColor
    else if (message.isAutomatic)
    {
      if (isSenderInMySquad(message))
        return voiceSquadColor
      else if (message.team != ::get_player_army_for_hud())
        return voiceEnemyColor
      else
        return voiceTeamColor
    }
    return ::g_mp_chat_mode.getModeById(message.mode).textColor
  }

  function isSenderMe(message)
  {
    return is_replay_playing() ?
      message.sender == spectatorWatchedHero.name :
      message.isMyself
  }

  function isSenderInMySquad(message)
  {
    if (is_replay_playing())
    {
      let player = ::u.search(::get_mplayers_list(::GET_MPLAYERS_LIST, true), @(p) p.name == message.sender)
      return ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
    }
    return ::g_squad_manager.isInMySquad(message.sender)
  }

  function updateAllLogs()
  {
    doForAllScenes(updateChatLog)
  }

  function updateChatLog(sceneData)
  {
    if (getCurView(sceneData) != mpChatView.CHAT)
      return
    let chat_log = sceneData.scene.findObject("chat_log")
    if (chat_log)
      chat_log.setValue(log_text)
  }

  function getLogText()
  {
    return log_text
  }

  function addNickToEdit(sceneData, user)
  {
    ::broadcastEvent("MpChatInputRequested", { activate = true })

    let inputObj = sceneData.scene.findObject("chat_input")
    if (!inputObj) return

    ::add_text_to_editbox(inputObj, user + " ")
    selectChatEditbox(inputObj)
  }

  function getCurView(sceneData)
  {
    return (!sceneData.selfHideLog || isVisibleWithCursor(sceneData)) ? sceneData.curTab : mpChatView.CHAT
  }

  function isVisibleWithCursor(sceneData) {
    if (!isMouseCursorVisible)
      return false
    let parentObj = sceneData.handler?.scene
    return (parentObj?.isValid() ?? false) && parentObj.isVisible()
  }

  function updateTabs(sceneData)
  {
    let visible = !sceneData.selfHideLog || isVisibleWithCursor(sceneData)

    local obj = sceneData.scene.findObject("chat_tabs")
    if (::checkObj(obj))
    {
      if (obj.getValue() == -1)
        obj.setValue(sceneData.curTab)
      obj.show(visible)
    }
    obj = sceneData.scene.findObject("chat_log_tdiv")
    if (::checkObj(obj))
    {
      obj.height = visible ? obj?["max-height"] : null
      obj.scrollType = visible ? "" : "hidden"
    }
  }

  function getControlsAllowMask()
  {
    return isActive && canEnableChatInput()
      ? CtrlsInGui.CTRL_IN_MP_CHAT | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE | CtrlsInGui.CTRL_ALLOW_MP_CHAT
      : CtrlsInGui.CTRL_ALLOW_FULL
  }

  function onEventLoadingStateChange(params)
  {
    clearInputChat()
    modeInited = false
  }

  function clearInputChat()
  {
    chatInputText = ""
    ::chat_on_text_update(chatInputText)
  }
}

::is_chat_screen_allowed <- function is_chat_screen_allowed()
{
  return ::is_hud_visible() && !::is_menu_state()
}

::loadGameChatToObj <- function loadGameChatToObj(obj, chatBlk, handler, p = MP_CHAT_PARAMS)
{
  return ::get_game_chat_handler().loadScene(obj, chatBlk, handler, MP_CHAT_PARAMS.__merge(p))
}

::detachGameChatSceneData <- function detachGameChatSceneData(sceneData)
{
  sceneData.scene = null
  ::get_game_chat_handler().cleanScenesList()
  ::handlersManager.updateControlsAllowMask()
}

::game_chat_input_toggle_request <- function game_chat_input_toggle_request(toggle)
{
  ::toggle_ingame_chat(toggle)
}

::enable_game_chat_input <- function enable_game_chat_input(value) // called from client
{
  if (value)
    ::broadcastEvent("MpChatInputRequested")

  let handler = ::get_game_chat_handler()
  if (value && !handler.hasEnableChatMode) {
    chat_system_message(loc("chat/no_chat"))
    return
  }
  if (!value || handler.canEnableChatInput())
    handler.enableChatInput(value)
}

::hide_game_chat_scene_input <- function hide_game_chat_scene_input(sceneData, value)
{
  ::get_game_chat_handler().hideChatInput(sceneData, value)
}

::clear_game_chat <- function clear_game_chat()
{
  ::debugTableData(ingame_chat)
  ingame_chat.clearLog()
}

::get_gamechat_log_text <- function get_gamechat_log_text()
{
  return ::get_game_chat_handler().getLogText()
}


::add_text_to_editbox <- function add_text_to_editbox(obj, text)
{
  let value = obj.getValue()
  let pos = obj.getIntProp(::dagui_propid.get_name_id(":behaviour_edit_position_pos"), -1)
  if (pos > 0 && pos < value.len()) // warning disable: -range-check
    obj.setValue(value.slice(0, pos) + text + value.slice(pos))
  else
    obj.setValue(value + text)
}

::chat_system_message <- function chat_system_message(text)
{
  ingame_chat.onIncomingMessage("", text, false, 0, true)
}

::add_tags_for_mp_players <- function add_tags_for_mp_players()
{
  let tbl = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
  if (tbl)
  {
    foreach(block in tbl)
      if(!block.isBot)
        ::clanUserTable[block.name] <- ::getTblValue("clanTag", block, "")
  }
}


::get_player_tag <- function get_player_tag(playerNick)
{
  if(!(playerNick in ::clanUserTable))
    ::add_tags_for_mp_players()
  return ::getTblValue(playerNick, ::clanUserTable, "")
}
