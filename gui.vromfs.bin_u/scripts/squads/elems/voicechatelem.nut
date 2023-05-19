//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")
let { get_option_voicechat } = require("chat")

const MAX_VOICE_ELEMS_IN_GC = 2

elemModelType.addTypes({
  VOICE_CHAT = {

    init = @() subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventVoiceChatStatusUpdated = @(_p) this.notify([])
    onEventSquadStatusChanged = @(_p) this.notify([])
    onEventVoiceChatOptionUpdated = @(_p) this.notify([])
    onEventSquadDataUpdated = @(_p) this.notify([])
    onEventClanInfoUpdate = @(_p) this.notify([])
  }
})


elemViewType.addTypes({
  VOICE_CHAT = {
    model = elemModelType.VOICE_CHAT

    updateView = function(obj, _params) {
      if (!::g_login.isLoggedIn())
        return

      let nestObj = obj.getParent().getParent()
      if (!checkObj(nestObj))
        return

      let isWidgetVisible = nestObj.getFinalProp("isClanOnly") != "yes" ||
        (get_option_voicechat()
         && chatStatesCanUseVoice()
         && !::g_squad_manager.isInSquad()
         && !!::my_clan_info)
      nestObj.show(isWidgetVisible)

      if (!isWidgetVisible)
        return

      let childRequired = ::g_squad_manager.isInSquad() ? ::g_squad_manager.MAX_SQUAD_SIZE
        : ::my_clan_info ? ::my_clan_info.mlimit
        : 0

      if (obj.childrenCount() < childRequired) {
        if (this.isAnybodyTalk())
          obj.getScene().performDelayed(this, function() {
            if (!obj.isValid())
              return

            this.fillContainer(obj, childRequired)
            this.updateMembersView(obj, nestObj)
          })
      }
      else
        this.updateMembersView(obj, nestObj)
    }

    isAnybodyTalk = function() {
      if (::g_squad_manager.isInSquad()) {
        foreach (uid, _member in ::g_squad_manager.getMembers())
          if (::getContact(uid)?.voiceStatus == voiceChatStats.talking)
            return true
      }
      else if (::my_clan_info)
        foreach (member in ::my_clan_info.members)
          if (::getContact(member.uid)?.voiceStatus == voiceChatStats.talking)
            return true

      return false
    }

    updateMembersView = function(obj, nestObj) {
      local memberIndex = 0
      if (::g_squad_manager.isInSquad()) {
        memberIndex = 1
        let leader = ::g_squad_manager.getSquadLeaderData()
        foreach (uid, member in ::g_squad_manager.getMembers())
          this.updateMemberView(obj, member == leader ? 0 : memberIndex++, uid)
      }
      else if (::my_clan_info)
        foreach (member in ::my_clan_info.members)
          this.updateMemberView(obj, memberIndex++, member.uid)

      while (memberIndex < obj.childrenCount())
        this.updateMemberView(obj, memberIndex++, null)

      let emptyVoiceObj = nestObj.findObject("voice_chat_no_activity")
      if (checkObj(emptyVoiceObj))
        emptyVoiceObj.fade = !this.isAnybodyTalk() ? "in" : "out"
    }

    updateMemberView = function(obj, objIndex, uid) {
      let memberObj = objIndex < obj.childrenCount() ? obj.getChild(objIndex) : null
      if (!checkObj(memberObj))
        return

      let contact = ::getContact(uid)
      let isTalking = contact?.voiceStatus == voiceChatStats.talking
      memberObj.fade = isTalking ? "in" : "out"
      if (isTalking)
        memberObj.findObject("users_name").setValue(contact?.getName() ?? "")
    }

    fillContainer = function(obj, childRequired) {
      let data = handyman.renderCached("%gui/chat/voiceChatElement.tpl",
        { voiceChatElement = array(childRequired, {}) })
      obj.getScene().replaceContentFromText(obj, data, data.len(), this)

      let heightEnd = obj.getParent().getFinalProp("isSmall") == "yes"
        ? ::g_dagui_utils.toPixels(::get_cur_gui_scene(), "1@gamercardHeight") /
            MAX_VOICE_ELEMS_IN_GC
        : ::g_dagui_utils.toPixels(::get_cur_gui_scene(), "1@voiceChatBaseIconHeight") +
            ::g_dagui_utils.toPixels(::get_cur_gui_scene(), "1@blockInterval")

      for (local i = 0; i < obj.childrenCount(); i++)
        obj.getChild(i)["height-end"] = heightEnd.tointeger().tostring()
    }
  }
})

return {}
