//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { startsWith, slice } = require("%sqstd/string.nut")

let enums = require("%sqStdLibs/helpers/enums.nut")
::g_chat_thread_tag <- {
  types = []
}

::g_chat_thread_tag._setThreadInfoPropertyForBoolTag <- function _setThreadInfoPropertyForBoolTag(threadInfo, _valueString) {
  threadInfo[this.threadInfoParamName] = true
}
::g_chat_thread_tag._updateThreadWhenNoTagForBoolTag <- function _updateThreadWhenNoTagForBoolTag(threadInfo) {
  threadInfo[this.threadInfoParamName] = false
}
::g_chat_thread_tag._getTagStringBoolForBoolTag <- function _getTagStringBoolForBoolTag(threadInfo) {
  if (threadInfo[this.threadInfoParamName])
    return this.prefix
  return ""
}

::g_chat_thread_tag.template <- {
  prefix = ""
  threadInfoParamName = null
  isRegular = true //regular tags are converted direct to threadInfo params.
  isReadOnly = false //do not send this tag on modify tags

  checkTag = function(tag) {
    return startsWith(tag, this.prefix)
  }
  setThreadInfoProperty = function(threadInfo, valueString) {
    if (this.threadInfoParamName)
      threadInfo[this.threadInfoParamName] = valueString
  }
  updateThreadByTag = function(threadInfo, tag) {
    if (!this.isRegular || !this.checkTag(tag))
      return false
    this.setThreadInfoProperty(threadInfo, slice(tag, this.prefix.len()))
    return true
  }
  updateThreadWhenNoTag = function(_threadInfo) {}
  updateThreadBeforeTagsUpdate = function(_threadInfo) {}

  getTagString = function(threadInfo) {
    if (this.isReadOnly || !this.threadInfoParamName)
      return ""
    return this.prefix + threadInfo[this.threadInfoParamName]
  }
}

enums.addTypesByGlobalName("g_chat_thread_tag", {
  CUSTOM = {
    isRegular = false
  }

  OWNER = {
    prefix = "owner_"
    threadInfoParamName = "ownerUid"
  }

  NICK = {
    prefix = "nick_"
    threadInfoParamName = "ownerNick"
    setThreadInfoProperty = function(threadInfo, valueString) {
      threadInfo[this.threadInfoParamName] = ::gchat_unescape_target(valueString)
    }
  }

  CLAN = {
    prefix = "clan_"
    threadInfoParamName = "ownerClanTag"
  }

  ONLINE = {
    prefix = "online_"
    threadInfoParamName = "membersAmount"
    isReadOnly = true

    setThreadInfoProperty = function(threadInfo, valueString) {
      threadInfo[this.threadInfoParamName] = to_integer_safe(valueString)
    }
    updateThreadWhenNoTag = function(threadInfo) {
      this.setThreadInfoProperty(threadInfo, 0)
    }
  }

  HIDDEN = {
    prefix = "hidden"
    threadInfoParamName = "isHidden"
    setThreadInfoProperty = ::g_chat_thread_tag._setThreadInfoPropertyForBoolTag
    updateThreadWhenNoTag = ::g_chat_thread_tag._updateThreadWhenNoTagForBoolTag
    getTagString          = ::g_chat_thread_tag._getTagStringBoolForBoolTag
  }

  PINNED = {
    prefix = "pinned"
    threadInfoParamName = "isPinned"
    setThreadInfoProperty = ::g_chat_thread_tag._setThreadInfoPropertyForBoolTag
    updateThreadWhenNoTag = ::g_chat_thread_tag._updateThreadWhenNoTagForBoolTag
    getTagString          = ::g_chat_thread_tag._getTagStringBoolForBoolTag
  }

  TIME_STAMP = {
    prefix = "stamp_"
    threadInfoParamName = "timeStamp"
    isReadOnly = true

    setThreadInfoProperty = function(threadInfo, valueString) {
      threadInfo[this.threadInfoParamName] = to_integer_safe(valueString)
    }
    updateThreadWhenNoTag = function(threadInfo) {
      this.setThreadInfoProperty(threadInfo, -1)
    }
  }

  LANG = {
    prefix = "lang_"
    threadInfoParamName = "langs"

    updateThreadBeforeTagsUpdate = function(threadInfo) {
      threadInfo[this.threadInfoParamName].clear()
    }
    setThreadInfoProperty = function(threadInfo, valueString) {
      threadInfo[this.threadInfoParamName].insert(0, valueString) //tags checked in inverted order
    }
    getTagString = function(threadInfo) {
      threadInfo.sortLangList()
      let tags = threadInfo[this.threadInfoParamName].map((@(prefix) function(val) { return prefix + val })(this.prefix))
      return ",".join(tags, true)
    }
  }

  CATEGORY = {
    prefix = "cat_"
    threadInfoParamName = "category"

    setThreadInfoProperty = function(threadInfo, valueString) {
      let categories = ::g_chat_categories.list
      let category = (valueString in categories) ? valueString : ::g_chat_categories.defaultCategoryName
      threadInfo[this.threadInfoParamName] = category
    }

    updateThreadWhenNoTag = function(threadInfo) {
      threadInfo[this.threadInfoParamName] = ::g_chat_categories.defaultCategoryName
    }
  }
})

::g_chat_thread_tag.types.sort(function(a, b) {
  if (a.isRegular != b.isRegular)
    return a.isRegular ? -1 : 1
  return 0
})
