from "%sqstd/string.nut" import clearBorderSymbolsMultiline, replace
from "console" import register_command
from "mission" import get_mplayers_list, GET_MPLAYERS_LIST
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CHAT_FILTER, USEROPT_ONLY_FRIENDLIST_CONTACT } = require("%scripts/options/optionsExtNames.nut")
let { isPlayerNickInContacts, isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { clanUserTable } = require("%scripts/contacts/contactsListState.nut")

function getChatObject(scene) {
  if (!checkObj(scene))
    scene = null
  let guiScene = get_gui_scene()
  local chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  if (!chatObj) {
    guiScene.appendWithBlk(scene ? scene : "", "tdiv { id:t='menuChat_scene' }")
    chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  }
  return chatObj
}

function isUserBlockedByPrivateSetting(uid = null, name = "") {
  let checkUid = uid != null
  let privateValue = get_gui_option_in_mode(USEROPT_ONLY_FRIENDLIST_CONTACT, OPTIONS_MODE_GAMEPLAY)
  return (privateValue && !isPlayerInFriendsGroup(uid, checkUid, name))
    || isPlayerNickInContacts(name, EPL_BLOCKLIST)
}

let { validateChatMessage } = require("%scripts/chat/localizedMessages.nut")

function validateThreadTitle(title) {
  local res = title.replace("\\n", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = validateChatMessage(res, true)
  return res
}

function prepareThreadTitleToSend(title) {
  let res = validateThreadTitle(title)
  return res.replace("\n", "<br>")
}

function restoreReceivedThreadTitle(title) {
  local res = title.replace("\\n", "\n")
  res = res.replace("<br>", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = validateChatMessage(res, true)
  return res
}

local chat_filter_for_myself = false
register_command(function() {
  chat_filter_for_myself = !chat_filter_for_myself
  console_print($"filter_myself: {chat_filter_for_myself}")
}, "chat.toggle_filter_myself")


function filterMessageText(text, isMyMessage) {
  if (isMyMessage && !chat_filter_for_myself)
    return text

  if (get_option(USEROPT_CHAT_FILTER).value)
    return dirtyWordsFilter.checkPhrase(text)
  return text
}

function addTagsForMpPlayers() {
  let tbl = get_mplayers_list(GET_MPLAYERS_LIST, true)
  if (!tbl)
    return

  let res = {}
  foreach (block in tbl)
    if (!block.isBot)
      res[block.name] <- block?.clanTag ?? ""

  if (res.len() > 0)
    clanUserTable.mutate(@(v) v.__update(res))
}

function getPlayerTag(playerNick) {
  if (!(playerNick in clanUserTable.get()))
    addTagsForMpPlayers()
  return clanUserTable.get()?[playerNick] ?? ""
}

function filterNameFromHtmlCodes(name) {
  return replace(replace(name, "%20", " "),  "%40", "@")
}

function addTextToEditbox(obj, text) {
  let value = obj.getValue()
  let pos = obj.getIntProp(dagui_propid_get_name_id(":behaviour_edit_position_pos"), -1)
  if (pos > 0 && pos < value.len()) 
    obj.setValue("".concat(value.slice(0, pos), text, value.slice(pos)))
  else
    obj.setValue($"{value}{text}")
}

return {
  getChatObject
  isUserBlockedByPrivateSetting
  validateThreadTitle
  prepareThreadTitleToSend
  restoreReceivedThreadTitle
  filterMessageText
  getPlayerTag
  filterNameFromHtmlCodes
  addTextToEditbox
  addTagsForMpPlayers
}