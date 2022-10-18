from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let platformModule = require("%scripts/clientState/platform.nut")
let { clearBorderSymbolsMultiline } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_gui_option } = require("guiOptions")

::gui_modal_ban <- function gui_modal_ban(playerInfo, cLog = null) {
  ::handlersManager.loadHandler(::gui_handlers.BanHandler, { player = playerInfo, chatLog = cLog })
}

::gui_modal_complain <- function gui_modal_complain(playerInfo, cLog = null)
{
  if (!::tribunal.canComplaint())
    return

  ::handlersManager.loadHandler(::gui_handlers.ComplainHandler, { pInfo = playerInfo, chatLog = cLog })
}

let chatLogToString = function(chatLog)
{
  if(!::u.isTable(chatLog))
  {
    ::script_net_assert_once("Chatlog value is not a table", "Invalid type of chatlog")
    return ""
  }

  local res = ::save_to_json(chatLog)
  local size = res.len()
  local idx = 0
  while(size > 29300)
    size -= ::save_to_json(chatLog.chatLog[idx++]).len() + 1
  if (idx > 0)
  {
    chatLog.chatLog = chatLog.chatLog.slice(idx)
    res = ::save_to_json(chatLog)
  }
  return res
}

::gui_handlers.BanHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/complain.blk"
  wndType = handlerType.MODAL

  player = null
  playerName = null
  optionsList = null
  chatLog = null

  function initScreen()
  {
    if (!this.scene || !player || !canBan())
      return this.goBack()

    playerName = getTblValue("name", player, "")
    if (!getTblValue("uid", player))
    {
      this.taskId = ::find_contact_by_name_and_do(playerName, Callback(onPlayerFound, this))
      if (this.taskId!=null && this.taskId<0)
      {
        notFoundPlayerMsg()
        return
      }
    }

    let titleObj = this.scene.findObject("complaint_title")
    if (checkObj(titleObj))
      titleObj.setValue(loc("contacts/moderator_ban/title"))

    let nameObj = this.scene.findObject("complain_text")
    if (checkObj(nameObj))
      nameObj.setValue(loc("clan/nick") + loc("ui/colon"))

    let clanTag = getTblValue("clanTag", player, "")
    let targetObj = this.scene.findObject("complain_target")
    if (checkObj(targetObj))
      targetObj.setValue((clanTag.len() > 0? (clanTag + " ") : "") + platformModule.getPlayerName(playerName))

    let options = [
      ::USEROPT_COMPLAINT_CATEGORY,
      ::USEROPT_BAN_PENALTY,
      ::USEROPT_BAN_TIME
    ]
    optionsList = []
    foreach(o in options)
      optionsList.append(::get_option(o))

    let optionsBox = this.scene.findObject("options_rows_div")
    let objForClones = optionsBox.getChild(0)
    for(local i=1; i<=optionsList.len(); i++)
    {
      let idx = (i<optionsList.len())? i : 0
      let opt = optionsList[idx]
      local optRow = null
      if (idx==0)
        optRow = objForClones
      else
        optRow = objForClones.getClone(optionsBox, this)

      optRow.findObject("option_name").setValue(loc("options/" + opt.id))
      let typeObj = optRow.findObject("option_list")
      let data = ::create_option_list(opt.id, opt.items, opt.value, null, false)
      this.guiScene.replaceContentFromText(typeObj, data, data.len(), this)
      typeObj.id = opt.id
    }

    onTypeChange()
    updateButtons()
  }

  function canBan()
  {
    return ::myself_can_devoice() || ::myself_can_ban()
  }

  function notFoundPlayerMsg()
  {
    this.msgBox("incorrect_user", loc("chat/error/item-not-found", { nick = platformModule.getPlayerName(playerName) }),
        [
          ["ok", function() { this.goBack() } ]
        ], "ok")
  }

  function updateButtons()
  {
    let haveUid = getTblValue("uid", player) != null
    this.showSceneBtn("info_loading", !haveUid)
    this.showSceneBtn("btn_send", haveUid)
  }

  function onPlayerFound(contact)
  {
    if (!contact)
      return notFoundPlayerMsg()

    player = contact
    if (checkObj(this.scene))
      updateButtons()
  }

  onTypeChange = @() ::select_editbox(this.scene.findObject("complaint_text"))

  function onApply()
  {
    if (!canBan())
      return this.goBack()

    let comment = clearBorderSymbolsMultiline(  this.scene.findObject("complaint_text").getValue()  )
    if (comment.len() < 10)
    {
      this.msgBox("need_text", loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    let uid = getTblValue("uid", player)
    if (!uid)
      return

    foreach(opt in optionsList)
    {
      let obj = this.scene.findObject(opt.id)
      ::set_option(opt.type, obj.getValue(), opt)
    }

    let duration = get_gui_option(::USEROPT_BAN_TIME)
    let category = get_gui_option(::USEROPT_COMPLAINT_CATEGORY)
    let penalty =  get_gui_option(::USEROPT_BAN_PENALTY)

    log(format("%s user: %s, for %s, for %d sec.\n comment: %s",
                       penalty, playerName, category, duration, comment))
    this.taskId = ::char_ban_user(uid, duration, "", category, penalty,
                           comment, ""/*hidden_note*/, chatLogToString(chatLog ?? {}))
    if (this.taskId >= 0)
    {
      ::set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/send"))
      this.afterSlotOp = function()
        {
          log("[IRC] sending /reauth " + playerName)
          ::gchat_raw_command("reauth " + ::gchat_escape_target(playerName))
          this.goBack()
        }
    }
  }
}

::gui_handlers.ComplainHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  optionsList = null
  location = ""
  clanInfo = ""
  pInfo = null
  chatLog = null
  scene = null
  task = ""
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/complain.blk"

  function initScreen()
  {
    if (!scene || !pInfo || typeof(pInfo) != "table")
      return this.goBack()

    let gameMode = "GameMode = " + loc(format("multiplayer/%sMode", ::get_game_mode_name(::get_game_mode())))
    location = gameMode
    if (chatLog != null)
    {
      if ("roomId" in pInfo && "roomName" in pInfo && pInfo.roomName != "")
        location = "Main Chat, Channel = " + pInfo.roomName + " (" + pInfo.roomId + ")"
      else
        location = "In-game Chat; " + gameMode
    }
    else
      chatLog = {}

    local pName = platformModule.getPlayerName(pInfo.name)
    local clanTag
    if("clanData" in pInfo)
    {
      let clanData = pInfo.clanData
      clanTag = ("tag" in clanData) ? clanData.tag : null

      clanInfo = ("id" in clanData ? "clan id = " + clanData.id + "\n" : "") +
                ("tag" in clanData ? "clan tag = " + clanData.tag + "\n" : "") +
                ("name" in clanData ? "clan name = " + clanData.name + "\n" : "") +
                ("slogan" in clanData ? "clan slogan = " + clanData.slogan + "\n" : "") +
                ("desc" in clanData ? "clan description = " + clanData.desc : "")
    }
    clanTag = clanTag || ( ("clanTag" in pInfo && pInfo.clanTag != "") ? pInfo.clanTag : null )
    pName = clanTag ? (clanTag + " " + pName) : pName

    let titleObj = scene.findObject("complaint_title")
    if (checkObj(titleObj))
      titleObj.setValue(loc("mainmenu/btnComplain"))

    let nameObj = scene.findObject("complain_text")
    if (checkObj(nameObj))
      nameObj.setValue(loc("clan/nick") + loc("ui/colon"))
    let targetObj = scene.findObject("complain_target")
    if (checkObj(targetObj))
      targetObj.setValue(pName)

    let typeObj = scene.findObject("option_list")

    optionsList = []
    let option = ::get_option(::USEROPT_COMPLAINT_CATEGORY)
    optionsList.append(option)
    let data = ::create_option_list(option.id, option.items, option.value, null, false)
    this.guiScene.replaceContentFromText(typeObj, data, data.len(), this)
    typeObj.id = option.id

    onTypeChange()
  }

  onTypeChange = @() ::select_editbox(scene.findObject("complaint_text"))

  function collectThreadListForTribunal()
  {
    let threads = []
    foreach( t in ::g_chat_latest_threads.getList())
    {
      threads.append({  tags      = t.getFullTagsString(),
                        title     = t.title,
                        numPosts  = t.numPosts,
                        owner     = t.getOwnerText()       })
    }
    return threads
  }

  function collectUserDetailsForTribunal( src )
  {
    let res = {};

    if ( src != null )
    {
      foreach(key in ["kills", "teamKills", "name", "clanTag", "groundKills", "awardDamage", "navalKills", "exp", "deaths"])
      {
        res[key] <- ((key in src)&&(src[key] != null))? src[key] : "<N/A>";
      }
      res["uid"] <- (("userId" in src) && src.userId) || "<N/A>" //in mplayer uid not the same like in other places. userId is real uid.
    }

    return res;
  }

  function onApply()
  {
    if (!this.isValid())
      return

    let user_comment = clearBorderSymbolsMultiline( scene.findObject("complaint_text").getValue() )
    if (user_comment.len() < 10)
    {
      this.msgBox("need_text", loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    let option = ::get_option(::USEROPT_COMPLAINT_CATEGORY)
    let cValue = scene.findObject(option.id).getValue()
    let category = (cValue in option.values)? option.values[cValue] : option.values[0]
    let details = ::save_to_json({
      own      = collectUserDetailsForTribunal( ::get_local_mplayer() ),
      offender = collectUserDetailsForTribunal( pInfo ),
      chats    = collectThreadListForTribunal()
    });

    chatLog.location <- location
    chatLog.clanInfo <- clanInfo
    let strChatLog = chatLogToString(chatLog)

    log("Send complaint " + category + ": \ncomment = " + user_comment + ", \nchatLog = " + strChatLog + ", \ndetails = " + details)
    log("pInfo:")
    debugTableData(pInfo)

    this.taskId = -1
    if (("userId" in pInfo) && pInfo.userId)
      this.taskId = ::send_complaint_by_uid(pInfo.userId, category, user_comment, strChatLog, details)
    else if ("name" in pInfo)
      this.taskId = ::send_complaint_by_nick(pInfo.name, category, user_comment, strChatLog, details)
    else
      this.taskId = ::send_complaint(pInfo.id, category, user_comment, strChatLog, details)
    if (this.taskId >= 0)
    {
      ::set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/send"))
      this.afterSlotOp = this.goBack
    }
  }
}
