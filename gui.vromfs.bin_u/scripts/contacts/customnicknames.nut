from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import contactEvent

let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isNamePassing } = require("%scripts/dirtyWordsFilter.nut")
let regexp2 = require("regexp2")
let { cutPlayerNamePrefix, cutPlayerNamePostfix } = require("%scripts/user/nickTools.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")

const CUSTOM_NICKS_SAVE_ID = "contacts/custom_nicks"
const CUSTOM_NICK_MARKER = "*"
const MAX_NICK_LENGHT = 16

let validateNickRegexp = regexp2(@"[^_0-9a-zA-Z]")

local isInited = false
local uidToCustomNick = {}

function initOnce() {
  if (isInited || !::g_login.isProfileReceived() || !hasFeature("CustomNicks"))
    return

  isInited = true

  let blk = loadLocalAccountSettings(CUSTOM_NICKS_SAVE_ID, null)
  if (!isDataBlock(blk))
    return

  uidToCustomNick = convertBlk(blk)
}

function invalidateCache() {
  uidToCustomNick.clear()
  isInited = false
}

function changeCustomNick(contact, customNick) {
  initOnce()
  if (!isInited)
    return

  let contactName = cutPlayerNamePrefix(cutPlayerNamePostfix(contact.name))
  if (customNick == contactName) {
    if (contact.uid in uidToCustomNick)
      uidToCustomNick.$rawdelete(contact.uid)
    else
      return
  }
  else
    uidToCustomNick[contact.uid] <- customNick

  saveLocalAccountSettings(CUSTOM_NICKS_SAVE_ID, uidToCustomNick)
}

function getCustomNick(contact) {
  initOnce()
  if (!isInited)
    return null

  return (contact?.uid in uidToCustomNick)
    ? $"{uidToCustomNick[contact.uid]}{CUSTOM_NICK_MARKER}"
    : null
}

let openNickEditBox = @(contact) openEditBoxDialog({
  title = loc("mainmenu/chooseName")
  label = loc("choose_nickname_req")
  maxLen = MAX_NICK_LENGHT
  validateFunc = @(nick) validateNickRegexp.replace("", nick)
  editboxWarningTooltip = loc("invalid_nickname")
  checkWarningFunc = isNamePassing
  canCancel = true
  value = cutPlayerNamePrefix(cutPlayerNamePostfix(contact.name))

  function okFunc(nick) {
    if (nick == "" || !isNamePassing(nick)) {
      showInfoMsgBox(loc("invalid_nickname"), "guest_login_invalid_nickname")
      return
    }
    changeCustomNick(contact, nick)
    broadcastEvent(contactEvent.CONTACTS_UPDATED)
  }
})

addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
})

return {
  openNickEditBox
  changeCustomNick
  getCustomNick
}