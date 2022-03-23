let enums = require("%sqStdLibs/helpers/enums.nut")
::g_chat_thread_tag <- {
  types = []
}

g_chat_thread_tag._setThreadInfoPropertyForBoolTag <- function _setThreadInfoPropertyForBoolTag(threadInfo, valueString)
{
  threadInfo[threadInfoParamName] = true
}
g_chat_thread_tag._updateThreadWhenNoTagForBoolTag <- function _updateThreadWhenNoTagForBoolTag(threadInfo)
{
  threadInfo[threadInfoParamName] = false
}
g_chat_thread_tag._getTagStringBoolForBoolTag <- function _getTagStringBoolForBoolTag(threadInfo)
{
  if (threadInfo[threadInfoParamName])
    return prefix
  return ""
}

::g_chat_thread_tag.template <- {
  prefix = ""
  threadInfoParamName = null
  isRegular = true //regular tags are converted direct to threadInfo params.
  isReadOnly = false //do not send this tag on modify tags

  checkTag = function(tag)
  {
    return ::g_string.startsWith(tag, prefix)
  }
  setThreadInfoProperty = function(threadInfo, valueString)
  {
    if (threadInfoParamName)
      threadInfo[threadInfoParamName] = valueString
  }
  updateThreadByTag = function(threadInfo, tag)
  {
    if (!isRegular || !checkTag(tag))
      return false
    setThreadInfoProperty(threadInfo, ::g_string.slice(tag, prefix.len()))
    return true
  }
  updateThreadWhenNoTag = function(threadInfo) {}
  updateThreadBeforeTagsUpdate = function(threadInfo) {}

  getTagString = function(threadInfo)
  {
    if (isReadOnly || !threadInfoParamName)
      return ""
    return prefix + threadInfo[threadInfoParamName]
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
    setThreadInfoProperty = function(threadInfo, valueString)
    {
      threadInfo[threadInfoParamName] = ::gchat_unescape_target(valueString)
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

    setThreadInfoProperty = function(threadInfo, valueString)
    {
      threadInfo[threadInfoParamName] = ::to_integer_safe(valueString)
    }
    updateThreadWhenNoTag = function(threadInfo)
    {
      setThreadInfoProperty(threadInfo, 0)
    }
  }

  HIDDEN = {
    prefix ="hidden"
    threadInfoParamName = "isHidden"
    setThreadInfoProperty = ::g_chat_thread_tag._setThreadInfoPropertyForBoolTag
    updateThreadWhenNoTag = ::g_chat_thread_tag._updateThreadWhenNoTagForBoolTag
    getTagString          = ::g_chat_thread_tag._getTagStringBoolForBoolTag
  }

  PINNED = {
    prefix ="pinned"
    threadInfoParamName = "isPinned"
    setThreadInfoProperty = ::g_chat_thread_tag._setThreadInfoPropertyForBoolTag
    updateThreadWhenNoTag = ::g_chat_thread_tag._updateThreadWhenNoTagForBoolTag
    getTagString          = ::g_chat_thread_tag._getTagStringBoolForBoolTag
  }

  TIME_STAMP = {
    prefix ="stamp_"
    threadInfoParamName = "timeStamp"
    isReadOnly = true

    setThreadInfoProperty = function(threadInfo, valueString)
    {
      threadInfo[threadInfoParamName] = ::to_integer_safe(valueString)
    }
    updateThreadWhenNoTag = function(threadInfo)
    {
      setThreadInfoProperty(threadInfo, -1)
    }
  }

  LANG = {
    prefix ="lang_"
    threadInfoParamName = "langs"

    updateThreadBeforeTagsUpdate = function(threadInfo)
    {
      threadInfo[threadInfoParamName].clear()
    }
    setThreadInfoProperty = function(threadInfo, valueString)
    {
      threadInfo[threadInfoParamName].insert(0, valueString) //tags checked in inverted order
    }
    getTagString = function(threadInfo)
    {
      threadInfo.sortLangList()
      let tags = ::u.map(threadInfo[threadInfoParamName], (@(prefix) function(val) { return prefix + val })(prefix))
      return ::g_string.implode(tags, ",")
    }
  }

  CATEGORY = {
    prefix = "cat_"
    threadInfoParamName = "category"

    setThreadInfoProperty = function(threadInfo, valueString)
    {
      let categories = ::g_chat_categories.list
      let category = (valueString in categories) ? valueString : ::g_chat_categories.defaultCategoryName
      threadInfo[threadInfoParamName] = category
    }

    updateThreadWhenNoTag = function(threadInfo)
    {
      threadInfo[threadInfoParamName] = ::g_chat_categories.defaultCategoryName
    }
  }
})

::g_chat_thread_tag.types.sort(function(a, b) {
  if (a.isRegular != b.isRegular)
    return a.isRegular ? -1 : 1
  return 0
})
