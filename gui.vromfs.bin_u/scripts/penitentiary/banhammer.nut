//-file:plus-string
from "%scripts/dagui_natives.nut" import send_complaint_by_uid, myself_can_devoice, gchat_raw_command, gchat_escape_target, myself_can_ban, set_char_cb, send_complaint, get_game_mode_name, send_complaint_by_nick, char_ban_user
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { format } = require("string")
let { clearBorderSymbolsMultiline } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { select_editbox, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_option } = require("guiOptions")
let { get_game_mode, get_local_mplayer } = require("mission")
let { set_option } = require("%scripts/options/optionsExt.nut")
let time = require("%scripts/time.nut")
let { USEROPT_COMPLAINT_CATEGORY, USEROPT_BAN_PENALTY, USEROPT_BAN_TIME
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")

::gui_modal_ban <- function gui_modal_ban(playerInfo, cLog = null) {
  handlersManager.loadHandler(gui_handlers.BanHandler, { player = playerInfo, chatLog = cLog })
}

::gui_modal_complain <- function gui_modal_complain(playerInfo, cLog = null) {
  if (!::tribunal.canComplaint())
    return

  handlersManager.loadHandler(gui_handlers.ComplainHandler, { pInfo = playerInfo, chatLog = cLog })
}

let chatLogToString = function(chatLog) {
  if (!u.isTable(chatLog)) {
    script_net_assert_once("Chatlog value is not a table", "Invalid type of chatlog")
    return ""
  }

  local res = ::save_to_json(chatLog)
  local size = res.len()
  local idx = 0
  while (size > 29300)
    size -= ::save_to_json(chatLog.chatLog[idx++]).len() + 1
  if (idx > 0) {
    chatLog.chatLog = chatLog.chatLog.slice(idx)
    res = ::save_to_json(chatLog)
  }
  return res
}

gui_handlers.BanHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/complain.blk"
  wndType = handlerType.MODAL

  player = null
  playerName = null
  optionsList = null
  chatLog = null

  function initScreen() {
    if (!this.scene || !this.player || !this.canBan())
      return this.goBack()

    this.playerName = getTblValue("name", this.player, "")
    if (!getTblValue("uid", this.player)) {
      this.taskId = ::find_contact_by_name_and_do(this.playerName, Callback(this.onPlayerFound, this))
      if (this.taskId != null && this.taskId < 0) {
        this.notFoundPlayerMsg()
        return
      }
    }

    let titleObj = this.scene.findObject("complaint_title")
    if (checkObj(titleObj))
      titleObj.setValue(loc("contacts/moderator_ban/title"))

    let nameObj = this.scene.findObject("complain_text")
    if (checkObj(nameObj))
      nameObj.setValue(loc("clan/nick") + loc("ui/colon"))

    let clanTag = getTblValue("clanTag", this.player, "")
    let targetObj = this.scene.findObject("complain_target")
    if (checkObj(targetObj))
      targetObj.setValue((clanTag.len() > 0 ? ($"{clanTag} ") : "") + getPlayerName(this.playerName))

    let options = [
      USEROPT_COMPLAINT_CATEGORY,
      USEROPT_BAN_PENALTY,
      USEROPT_BAN_TIME
    ]
    this.optionsList = []
    foreach (o in options)
      this.optionsList.append(::get_option(o))

    let optionsBox = this.scene.findObject("options_rows_div")
    let objForClones = optionsBox.getChild(0)
    for (local i = 1; i <= this.optionsList.len(); i++) {
      let idx = (i < this.optionsList.len()) ? i : 0
      let opt = this.optionsList[idx]
      local optRow = null
      if (idx == 0)
        optRow = objForClones
      else
        optRow = objForClones.getClone(optionsBox, this)

      optRow.findObject("option_name").setValue(loc($"options/{opt.id}"))
      let typeObj = optRow.findObject("option_list")
      let data = ::create_option_list(opt.id, opt.items, opt.value, null, false)
      this.guiScene.replaceContentFromText(typeObj, data, data.len(), this)
      typeObj.id = opt.id
    }

    this.onTypeChange()
    this.updateButtons()
  }

  function canBan() {
    return ::myself_can_devoice() || myself_can_ban()
  }

  function notFoundPlayerMsg() {
    this.msgBox("incorrect_user", loc("chat/error/item-not-found", { nick = getPlayerName(this.playerName) }),
        [
          ["ok", function() { this.goBack() } ]
        ], "ok")
  }

  function updateButtons() {
    let haveUid = getTblValue("uid", this.player) != null
    showObjById("info_loading", !haveUid, this.scene)
    showObjById("btn_send", haveUid, this.scene)
  }

  function onPlayerFound(contact) {
    if (!contact)
      return this.notFoundPlayerMsg()

    this.player = contact
    if (checkObj(this.scene))
      this.updateButtons()
  }

  onTypeChange = @() select_editbox(this.scene.findObject("complaint_text"))

  function onApply() {
    if (!this.canBan())
      return this.goBack()

    let comment = clearBorderSymbolsMultiline(this.scene.findObject("complaint_text").getValue())
    if (comment.len() < 10) {
      this.msgBox("need_text", loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    let uid = getTblValue("uid", this.player)
    if (!uid)
      return

    foreach (opt in this.optionsList) {
      let obj = this.scene.findObject(opt.id)
      set_option(opt.type, obj.getValue(), opt)
    }

    let duration = get_gui_option(USEROPT_BAN_TIME)
    let category = get_gui_option(USEROPT_COMPLAINT_CATEGORY)
    let penalty =  get_gui_option(USEROPT_BAN_PENALTY)

    log(format("%s user: %s, for %s, for %d sec.\n comment: %s",
                       penalty, this.playerName, category, duration, comment))
    this.taskId = char_ban_user(uid, duration, "", category, penalty,
                           comment, "" /*hidden_note*/ , chatLogToString(this.chatLog ?? {}))
    if (this.taskId >= 0) {
      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/send"))
      this.afterSlotOp = function() {
          log($"[IRC] sending /reauth {this.playerName}")
          ::gchat_raw_command("reauth " + gchat_escape_target(this.playerName))
          this.goBack()
        }
    }
  }
}

gui_handlers.ComplainHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  optionsList = null
  location = ""
  clanInfo = ""
  pInfo = null
  chatLog = null
  scene = null
  task = ""
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/complain.blk"
  compliantCategory = ""

  function initScreen() {
    if (!this.scene || !this.pInfo || type(this.pInfo) != "table")
      return this.goBack()

    let gameMode = "GameMode = " + loc(format("multiplayer/%sMode", get_game_mode_name(get_game_mode())))
    this.location = gameMode
    if (this.chatLog != null) {
      if ("roomId" in this.pInfo && "roomName" in this.pInfo && this.pInfo.roomName != "")
        this.location = "Main Chat, Channel = " + this.pInfo.roomName + " (" + this.pInfo.roomId + ")"
      else
        this.location =$"In-game Chat; {gameMode}"
    }
    else
      this.chatLog = {}

    local pName = getPlayerName(this.pInfo?.playerName ?? this.pInfo.name)
    local clanTag
    if ("clanData" in this.pInfo) {
      let clanData = this.pInfo.clanData
      clanTag = ("tag" in clanData) ? clanData.tag : null

      this.clanInfo = ("id" in clanData ? $"clan id = {clanData.id}" + "\n" : "") +
                ("tag" in clanData ? $"clan tag = {clanData.tag}" + "\n" : "") +
                ("name" in clanData ? $"clan name = {clanData.name}" + "\n" : "") +
                ("slogan" in clanData ? $"clan slogan = {clanData.slogan}" + "\n" : "") +
                ("desc" in clanData ? $"clan description = {clanData.desc}" : "")
    }
    clanTag = clanTag || (("clanTag" in this.pInfo && this.pInfo.clanTag != "") ? this.pInfo.clanTag : null)
    pName = clanTag ? ($"{clanTag} {pName}") : pName

    let titleObj = this.scene.findObject("complaint_title")
    if (checkObj(titleObj))
      titleObj.setValue(loc("mainmenu/btnComplain"))

    let nameObj = this.scene.findObject("complain_text")
    if (checkObj(nameObj))
      nameObj.setValue(loc("clan/nick") + loc("ui/colon"))
    let targetObj = this.scene.findObject("complain_target")
    if (checkObj(targetObj))
      targetObj.setValue(pName)

    let typeObj = this.scene.findObject("option_list")

    this.optionsList = []
    let option = ::get_option(USEROPT_COMPLAINT_CATEGORY)
    this.optionsList.append(option)
    let data = ::create_option_list(option.id, option.items, option.value, null, false)
    this.guiScene.replaceContentFromText(typeObj, data, data.len(), this)
    typeObj.id = option.id

    this.fillComplaintText()
    this.onTypeChange()
  }

  function fillComplaintText() {
    let complaint_messages = this.scene.findObject("complaint_messages")
    let pi = this.pInfo
    if(this.chatLog?.chatLog == null)
      return
    let messages = this.chatLog.chatLog
      .filter(@(l) to_integer_safe(l.fromUid, 0, false) == pi.userId.tointeger())
      .map(function(l) {
        let fullName = ::g_contacts.getPlayerFullName(l.from, ::get_player_tag(l.from))
        let messageTime = l?.time ?? 0
        return "\n".join(l.msgs.map(@(msg) $"{messageTime > 0 ? time.secondsToString(messageTime, false) : ""} {fullName}: {msg}"))
      })
    complaint_messages.setValue("\n".join(messages, true))
  }

  function onTypeChange() {
    select_editbox(this.scene.findObject("complaint_text"))

    let option = ::get_option(USEROPT_COMPLAINT_CATEGORY)
    let cValue = this.scene.findObject(option.id).getValue()
    this.compliantCategory = (cValue in option.values) ? option.values[cValue] : option.values[0]
    let complaint_messages = this.scene.findObject("complaint_messages")
    let messages = complaint_messages.getValue()
    complaint_messages.show(messages != "" && ["FOUL", "ABUSE", "HATE", "SPAM"].contains(this.compliantCategory))
  }

  function collectThreadListForTribunal() {
    let threads = []
    foreach (t in ::g_chat_latest_threads.getList()) {
      threads.append({  tags      = t.getFullTagsString(),
                        title     = t.title,
                        numPosts  = t.numPosts,
                        owner     = t.getOwnerText()       })
    }
    return threads
  }

  function collectUserDetailsForTribunal(src) {
    let res = {};

    if (src != null) {
      foreach (key in ["kills", "teamKills", "name", "clanTag", "groundKills", "awardDamage", "navalKills", "exp", "deaths"]) {
        res[key] <- ((key in src) && (src[key] != null)) ? src[key] : "<N/A>";
      }
      res["uid"] <- (("userId" in src) && src.userId) || "<N/A>" //in mplayer uid not the same like in other places. userId is real uid.
    }

    return res;
  }

  function onApply() {
    if (!this.isValid())
      return

    let user_comment = clearBorderSymbolsMultiline(this.scene.findObject("complaint_text").getValue())
    if (user_comment.len() < 10 && !["FOUL", "ABUSE", "HATE", "SPAM"].contains(this.compliantCategory)) {
      this.msgBox("need_text", loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    if(this.compliantCategory == "BOT2") //2 different reasons for the complaint are sent under the same BOT category
      this.compliantCategory = "BOT"
    let details = ::save_to_json({
      own      = this.collectUserDetailsForTribunal(get_local_mplayer()),
      offender = this.collectUserDetailsForTribunal(this.pInfo),
      chats    = this.collectThreadListForTribunal()
    });

    this.chatLog.location <- this.location
    this.chatLog.clanInfo <- this.clanInfo
    let strChatLog = chatLogToString(this.chatLog)

    log($"Send complaint {this.compliantCategory}" + ": \ncomment = " + user_comment + ", \nchatLog = " + strChatLog + ", \ndetails = " + details)
    log("pInfo:")
    debugTableData(this.pInfo)

    this.taskId = -1
    if (("userId" in this.pInfo) && this.pInfo.userId)
      this.taskId = send_complaint_by_uid(this.pInfo.userId, this.compliantCategory, user_comment, strChatLog, details)
    else if ("name" in this.pInfo)
      this.taskId = send_complaint_by_nick(this.pInfo.name, this.compliantCategory, user_comment, strChatLog, details)
    else
      this.taskId = send_complaint(this.pInfo.id, this.compliantCategory, user_comment, strChatLog, details)
    if (this.taskId >= 0) {
      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/send"))
      this.afterSlotOp = this.goBack
    }
  }
}
