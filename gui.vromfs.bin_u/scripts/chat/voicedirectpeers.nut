from "%scripts/dagui_library.nut" import *
from "chat" import gchat_voice_set_allowed_direct_peers
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%sqstd/underscore.nut" import isEqual
from "%scripts/options/optionsExt.nut" import registerOption
from "%scripts/options/optionsExtNames.nut" import USEROPT_VOICE_DIRECT_PEERS, OPTIONS_MODE_GAMEPLAY
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%globalScripts/externalPlayerListConsts.nut" import EPL_FRIENDLIST, EPL_BLOCKLIST
from "%scripts/contacts/contactsConsts.nut" import EPLX_PS4_FRIENDS
from "%scripts/contacts/contactsListState.nut" import contactsByGroups
from "%scripts/squads/squadState.nut" import getMembers
from "%scripts/clans/clanState.nut" import myClanInfo
from "%appGlobals/login/loginState.nut" import isProfileReceived

const LEVELS = ["nobody", "no_strangers", "friends", "everyone"]
const DEFAULT_LEVEL = "no_strangers"

local lastRule = null

let toUserIds = @(uids) uids.map(@(uid) uid.tointeger()).sort()

function getAllowedUserIds(level) {
  let uids = {}
  foreach (uid, contact in contactsByGroups?[EPL_FRIENDLIST] ?? {})
    if (contact.contactServiceGroup != "myRequests")
      uids[uid] <- true
  foreach (uid, _ in contactsByGroups?[EPLX_PS4_FRIENDS] ?? {})
    uids[uid] <- true
  if (level == "no_strangers") {
    foreach (uid, _ in getMembers())
      uids[uid] <- true
    foreach (member in myClanInfo.get()?.members ?? [])
      uids[member.uid] <- true
  }
  return toUserIds(uids.keys())
}

function sendDirectPeersRule() {
  
  if (!isProfileReceived.get()) {
    lastRule = null
    return
  }
  let level = get_gui_option_in_mode(USEROPT_VOICE_DIRECT_PEERS, OPTIONS_MODE_GAMEPLAY, DEFAULT_LEVEL)
  let allowed = level == "nobody" ? false
    : level == "everyone" ? true
    : getAllowedUserIds(level)
  let rule = [allowed, level == "nobody" ? [] : toUserIds((contactsByGroups?[EPL_BLOCKLIST] ?? {}).keys())]
  if (isEqual(rule, lastRule))
    return
  lastRule = rule
  gchat_voice_set_allowed_direct_peers(rule[0], rule[1])
}

function fillVoiceDirectPeers(_optionId, descr, _context) {
  descr.id = "voice_direct_peers"
  descr.values = LEVELS
  descr.items = LEVELS.map(@(v) $"#options/voice_direct_peers/{v}")
  descr.defaultValue = DEFAULT_LEVEL
}

function setVoiceDirectPeers(value, descr, optionId) {
  let level = descr.values?[value]
  if (level == null)
    return
  set_gui_option_in_mode(optionId, level, OPTIONS_MODE_GAMEPLAY)
  sendDirectPeersRule()
}

registerOption(USEROPT_VOICE_DIRECT_PEERS, fillVoiceDirectPeers, setVoiceDirectPeers)

add_event_listener("ContactsGroupUpdate", @(_) sendDirectPeersRule())
add_event_listener("SquadDataUpdated", @(_) sendDirectPeersRule())
add_event_listener("SquadStatusChanged", @(_) sendDirectPeersRule())
myClanInfo.subscribe(@(_) sendDirectPeersRule())
isProfileReceived.subscribe(@(_) sendDirectPeersRule())
sendDirectPeersRule()
