from "%scripts/dagui_natives.nut" import clan_get_my_role, clan_get_my_clan_id, clan_get_role_rights
from "%scripts/dagui_library.nut" import *

let { is_in_clan, myClanInfo } = require("%scripts/clans/clanState.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let DataBlock  = require("DataBlock")
let { addPopup, removePopupByHandler } = require("%scripts/popups/popups.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { doWithAllGamercards } = require("%scripts/gamercard/gamercardHelpers.nut")

const CLAN_SEEN_CANDIDATES_SAVE_ID = "seen_clan_candidates"
const MAX_CANDIDATES_NICKNAMES_IN_POPUP = 5

local seenCandidatesBlk = null

let clanCandidatesPopupContext = {}

let setSeenCandidatesBlk = @(val) seenCandidatesBlk = val

let getMyClanCandidates = @() myClanInfo.get()?.candidates ?? []

function isHaveRightsToReviewCandidates() {
  if (!is_in_clan() || !hasFeature("Clans"))
    return false
  let rights = clan_get_role_rights(clan_get_my_role())
  return isInArray("MEMBER_ADDING", rights) || isInArray("MEMBER_REJECT", rights)
}

function getUnseenCandidatesCount() {
  if (!getMyClanCandidates().len() ||
    !isHaveRightsToReviewCandidates() || !seenCandidatesBlk)
    return 0

  local count = 0
  let clanCandidates = getMyClanCandidates()
  foreach (clanCandidate in clanCandidates) {
    let result = seenCandidatesBlk?[clanCandidate.uid]
    if (!result)
      count++
  }
  return count
}

function saveCandidates() {
  if (!isProfileReceived.get() || !isHaveRightsToReviewCandidates() || !seenCandidatesBlk)
    return
  saveLocalAccountSettings(CLAN_SEEN_CANDIDATES_SAVE_ID, seenCandidatesBlk)
}

function loadSeenCandidates() {
  let result = DataBlock()
  if (isProfileReceived.get() && isHaveRightsToReviewCandidates()) {
    let loaded = loadLocalAccountSettings(CLAN_SEEN_CANDIDATES_SAVE_ID, null)
    if (loaded != null)
      result.setFrom(loaded)
  }
  return result
}

function updateClanAlertIcon() {
  let needAlert = hasFeature("Clans") && getUnseenCandidatesCount() > 0
  doWithAllGamercards(function(scene) {
      showObjById("gc_clanAlert", needAlert, scene)
    })
}

function onClanCandidatesChanged() {
  if (!getUnseenCandidatesCount())
    removePopupByHandler(clanCandidatesPopupContext)

  saveCandidates()
  updateClanAlertIcon()
}

function markClanCandidatesAsViewed() {
  if (!isHaveRightsToReviewCandidates())
    return

  local clanInfoChanged = false
  let clanCandidates = getMyClanCandidates()
  foreach (clanCandidate in clanCandidates) {
    if (seenCandidatesBlk?[clanCandidate.uid] == true)
      continue

    seenCandidatesBlk[clanCandidate.uid] = true
    clanInfoChanged = true
  }
  if (clanInfoChanged)
    onClanCandidatesChanged()
}

function openClanRequestsWnd(candidatesData, clanId, owner) {
  loadHandler(gui_handlers.clanRequestsModal,
    {
      candidatesData = candidatesData,
      owner = owner
      clanId = clanId
    })
  markClanCandidatesAsViewed()
}

function parseSeenCandidates() {
  if (!hasFeature("Clans"))
    return

  if (!seenCandidatesBlk)
    seenCandidatesBlk = loadSeenCandidates()

  local isChanged = false
  let actualUids = {}
  let newCandidatesNicknames = []
  let clanCandidates = getMyClanCandidates()
  foreach (candidate in clanCandidates) {
    actualUids[candidate.uid] <- true
    if (seenCandidatesBlk?[candidate.uid] != null)
      continue
    seenCandidatesBlk[candidate.uid] <- false
    newCandidatesNicknames.append(getPlayerName(candidate.nick))
    isChanged = true
  }

  for (local i = seenCandidatesBlk.paramCount() - 1; i >= 0; i--) {
    let paramName = seenCandidatesBlk.getParamName(i)
    if (!(paramName in actualUids)) {
      isChanged = true
      seenCandidatesBlk[paramName] = null
    }
  }

  if (!isChanged)
    return

  local extraText = ""
  if (newCandidatesNicknames.len() > MAX_CANDIDATES_NICKNAMES_IN_POPUP) {
    extraText = loc("clan/moreCandidates",
      { count = newCandidatesNicknames.len() - MAX_CANDIDATES_NICKNAMES_IN_POPUP })
    newCandidatesNicknames.resize(MAX_CANDIDATES_NICKNAMES_IN_POPUP)
  }

  if (newCandidatesNicknames.len())
    addPopup(null,
      "".concat(loc("clan/requestReceived"), loc("ui/colon"),
        ", ".join(newCandidatesNicknames, true), $" {extraText}"),
      function() {
        let myClanCandidates = getMyClanCandidates()
        if (myClanCandidates.len())
          openClanRequestsWnd(myClanCandidates, clan_get_my_clan_id(), null)
      },
      null,
      clanCandidatesPopupContext)

  onClanCandidatesChanged()
}

return {
  setSeenCandidatesBlk

  getMyClanCandidates
  isHaveRightsToReviewCandidates
  getUnseenCandidatesCount
  markClanCandidatesAsViewed
  parseSeenCandidates
  openClanRequestsWnd
}