let platformModule = require("scripts/clientState/platform.nut")
let playerContextMenu = require("scripts/user/playerContextMenu.nut")
let { isCrossNetworkMessageAllowed } = require("scripts/chat/chatStates.nut")

const MAX_THREAD_LANG_VISIBLE = 3

::ChatThreadInfo <- class
{
  roomId = "" //threadRoomId
  lastUpdateTime = -1

  title = ""
  category = ""
  numPosts = 0
  customTags = null
  ownerUid = ""
  ownerNick = ""
  ownerClanTag = ""
  membersAmount = 0
  isHidden = false
  isPinned = false
  timeStamp = -1
  langs = null

  isValid = true

  constructor(threadRoomId, dataBlk = null) //dataBlk from chat response
  {
    roomId = threadRoomId
    isValid = roomId.len() > 0
    ::dagor.assertf(::g_chat_room_type.THREAD.checkRoomId(roomId), "Chat thread created with not thread id = " + roomId)
    langs = []

    updateInfo(dataBlk)
  }

  function markUpdated()
  {
    lastUpdateTime = ::dagor.getCurTime()
  }

  function invalidate()
  {
    isValid = false
  }

  function isOutdated()
  {
    return lastUpdateTime + ::g_chat.THREADS_INFO_TIMEOUT_MSEC < ::dagor.getCurTime()
  }

  function checkRefreshThread()
  {
    if (!isValid
        || !::g_chat.checkChatConnected()
        || lastUpdateTime + ::g_chat.THREAD_INFO_REFRESH_DELAY_MSEC > ::dagor.getCurTime()
       )
      return

    ::gchat_raw_command("xtmeta " + roomId)
  }

  function updateInfo(dataBlk)
  {
    if (!dataBlk)
      return

    title = ::g_chat.restoreReceivedThreadTitle(dataBlk.topic) || title
    if (title == "")
      title = roomId
    numPosts = dataBlk?.numposts ?? numPosts

    updateInfoTags(::u.isString(dataBlk?.tags) ? ::split(dataBlk.tags, ",") : [])
    if (ownerNick.len() && ownerUid.len())
      ::getContact(ownerUid, ownerNick, ownerClanTag)

    markUpdated()
  }

  function updateInfoTags(tagsList)
  {
    foreach(tagType in ::g_chat_thread_tag.types)
    {
      if (!tagType.isRegular)
        continue

      tagType.updateThreadBeforeTagsUpdate(this)

      local found = false
      for(local i = tagsList.len() - 1; i >= 0; i--)
        if (tagType.updateThreadByTag(this, tagsList[i]))
        {
          tagsList.remove(i)
          found = true
        }

      if (!found)
        tagType.updateThreadWhenNoTag(this)
    }
    customTags = tagsList
    sortLangList()
  }

  function getFullTagsString()
  {
    let resArray = []
    foreach(tagType in ::g_chat_thread_tag.types)
    {
      if (!tagType.isRegular)
        continue

      let str = tagType.getTagString(this)
      if (str.len())
        resArray.append(str)
    }
    resArray.extend(customTags)
    return ::g_string.implode(resArray, ",")
  }

  function sortLangList()
  {
    //usually only one lang in thread, but moderators can set some threads to multilang
    if (langs.len() < 2)
      return

    let unsortedLangs = clone langs
    langs.clear()
    foreach(langInfo in ::g_language.getGameLocalizationInfo())
    {
      let idx = unsortedLangs.indexof(langInfo.chatId)
      if (idx != null)
        langs.append(unsortedLangs.remove(idx))
    }
    langs.extend(unsortedLangs) //unknown langs at the end
  }

  function isMyThread()
  {
    return ownerUid == "" || ownerUid == ::my_user_id_str
  }

  function getTitle()
  {
    return ::g_chat.filterMessageText(title, isMyThread())
  }

  function getOwnerText(isColored = true, defaultColor = "")
  {
    if (!ownerNick.len())
      return ownerUid

    local res = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(ownerNick), ownerClanTag)
    if (isColored)
      res = ::colorize(::g_chat.getSenderColor(ownerNick, false, false, defaultColor), res)
    return res
  }

  function getRoomTooltipText()
  {
    local res = getOwnerText(true, "userlogColoredText")
    res += "\n" + ::loc("chat/thread/participants") + ::loc("ui/colon")
           + ::colorize("activeTextColor", membersAmount)
    res += "\n\n" + getTitle()
    return res
  }

  function isJoined()
  {
    return ::g_chat.isRoomJoined(roomId)
  }

  function join()
  {
    ::g_chat.joinThread(roomId)
  }

  function showOwnerMenu(position = null)
  {
    let contact = ::getContact(ownerUid, ownerNick, ownerClanTag)
    ::g_chat.showPlayerRClickMenu(ownerNick, roomId, contact, position)
  }

  function getJoinText()
  {
    return isJoined() ? ::loc("chat/showThread") : ::loc("chat/joinThread")
  }

  function getMembersAmountText()
  {
    return ::loc("chat/thread/participants") + ::loc("ui/colon") + membersAmount
  }

  function showThreadMenu(position = null)
  {
    let thread = this
    let menu = [
      {
        text = getJoinText()
        action = (@(thread) function() {
          thread.join()
        })(thread)
      }
    ]

    let contact = ::getContact(ownerUid, ownerNick, ownerClanTag)
    playerContextMenu.showMenu(contact, ::g_chat, {
      position = position
      roomId = roomId
      playerName = ownerNick
      extendButtons = menu
    })
  }

  function canEdit()
  {
    return ::is_myself_anyof_moderators()
  }

  function setObjValueById(objNest, id, value)
  {
    let obj = objNest.findObject(id)
    if (::checkObj(obj))
      obj.setValue(value)
  }

  function updateInfoObj(obj, updateActionBtn = false)
  {
    if (!::checkObj(obj))
      return

    obj.active = isJoined() ? "yes" : "no"

    if (updateActionBtn)
      setObjValueById(obj, "action_btn", getJoinText())

    setObjValueById(obj, "ownerName_" + roomId, getOwnerText())
    setObjValueById(obj, "thread_title", getTitle())
    setObjValueById(obj, "thread_members", getMembersAmountText())
    if (::g_chat.canChooseThreadsLang())
      fillLangIconsRow(obj)
  }

  function needShowLang()
  {
    return ::g_chat.canChooseThreadsLang()
  }

  function getLangsList()
  {
    let res = []
    local langInfo = {}
    if (langs.len() > MAX_THREAD_LANG_VISIBLE)
    {
      langInfo = ::g_language.getEmptyLangInfo()
      langInfo.icon = ""
      res.append(langInfo)
    }
    else
      foreach(langId in langs)
      {
        langInfo = ::g_language.getLangInfoByChatId(langId)
        if (langInfo)
          res.append(langInfo)
      }
    res.resize(MAX_THREAD_LANG_VISIBLE, ::g_language.getEmptyLangInfo())
    return res
  }

  function fillLangIconsRow(obj)
  {
    let contentObject = obj.findObject("thread_lang")
    let res = getLangsList()
    for(local i = 0; i < MAX_THREAD_LANG_VISIBLE; i++)
    {
      contentObject.getChild(i)["background-image"] = res[i].icon
    }
  }

  //It's like hidden, but must reveal when unhidden
  isConcealed = function() {
    if (!isCrossNetworkMessageAllowed(ownerNick))
      return true

    let contact = ::getContact(ownerUid, ownerNick, ownerClanTag)
    if (contact)
      return contact.isBlockedMe || contact.isInBlockGroup()

    return false
  }
}
