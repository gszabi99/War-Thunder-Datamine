from "%scripts/dagui_natives.nut" import get_nicks_find_result_blk, find_nicks_by_prefix
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState
from "%scripts/shop/shopCountriesList.nut" import checkCountry

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { contactsPlayers } = require("%scripts/contacts/contactsListState.nut")
let { requestUsersInfo, getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { missed_contacts_data } = require("%scripts/contacts/contactsInfo.nut")
let { getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let Contact = require("%scripts/contacts/contact.nut")
let { get_battle_type_by_ediff } = require("%scripts/difficulty.nut")
let { getGameModeById, getGameModeEvent } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnitClassIco, getFontIconByBattleType } = require("%scripts/unit/unitInfoTexts.nut")
let { getByPresenceParams } = require("%scripts/user/presenceType.nut")

function getContact(uid, nick = null, clanTag = null, forceUpdate = false) {
  if (!uid)
    return null

  if (hasFeature("ProfileIconInContact"))
    requestUsersInfo(uid)

  if (!(uid in contactsPlayers)) {
    if (nick != null) {
      let contact = Contact({ name = nick, uid = uid })
      contactsPlayers[uid] <- contact
      if (uid in missed_contacts_data)
        contact.update(missed_contacts_data.$rawdelete(uid))
      contact.updateMuteStatus()
    }
    else
      return null
  }

  let contact = contactsPlayers[uid]
  if (nick != null && (forceUpdate || contact.name == ""))
    contact.name = nick

  if (clanTag != null && (forceUpdate || !u.isEqual(contact.clanTag, clanTag)))
    contact.setClanTag(clanTag)

  return contact
}

function getContactTooltipBattleOrSquadStatusTxt(contact, squadStatus, presenceParams) {
  let { presenceType, presenceStatus } = presenceParams
  if (presenceType.typeName != "IDLE")
    return presenceType.getLocTextShort(presenceStatus)

  let { gameMode = null, country = null } = contact.getBattlePresenceDesc()
  let needShowSquadStatus = contact.squadPresence && squadStatus != squadMemberState.SQUAD_LEADER
    && squadStatus != squadMemberState.SQUAD_MEMBER_OFFLINE
  local statusTxt = ""
  if (gameMode && country)
    statusTxt = loc("ui/comma").concat(gameMode, country)
  else if (needShowSquadStatus)
    statusTxt = contact.squadPresence.getTextInTooltip()
  return statusTxt
}

::fillContactTooltip <- function fillContactTooltip(obj, contact, handler) {
  let customNick = getCustomNick(contact)
  local playerName = customNick == null
    ? contact.getName()
    : $"{contact.getName()}{loc("ui/parentheses/space", { text = customNick })}"
  let clanTag = hasFeature("Clans") ? contact.clanTag : null

  let wtName = contact.steamName == null || contact.name == ""
    ? ""
    : loc("war_thunder_nickname", { name = getPlayerName(contact.name) })

  let squadStatus = g_squad_manager.getPlayerStatusInMySquad(contact.uid)
  let squadLeaderTxt = squadStatus == squadMemberState.SQUAD_LEADER
    ? " ".concat(loc("ui/bullet"), loc("status/squad_leader"))
    : ""

  let title = contact.title != "" && contact.title != null
    ? loc($"title/{contact.title}")
    : ""

  let userInfo = contact.uid != "" ? getUserInfo(contact.uid) : null 
  let headerBackground = (userInfo?.background ?? "") != ""
    ? userInfo.background
    : "profile_header_default"

  let memberData = g_squad_manager.getMemberData(contact.uid)
  let presenceStatus = memberData?.presenceStatus
  let presenceType = getByPresenceParams(presenceStatus)
  let battleOrSquadStatusTxt = getContactTooltipBattleOrSquadStatusTxt(contact, squadStatus, { presenceType, presenceStatus })
  let onlineStatusColor = contact.onlinePresence.getColorInTooltip()

  let view = {
    name = colorize("@white", playerName)
    clanTag = clanTag ? colorize("@white", clanTag) : null
    wtName = colorize("@white", wtName)
    title = colorize("@white", title)
    icon = contact.steamAvatar ?? $"#ui/images/avatars/{contact.pilotIcon}.avif"
    headerBackground
    hasAvatarFrame = (userInfo?.frame ?? "") != ""
    frame = userInfo?.frame
    onlineStatusText = (presenceType.typeName == "IDLE") ? contact.onlinePresence.getTextInTooltip()
      : colorize(onlineStatusColor, presenceType.getLocStatusShort())
    battleOrSquadStatusTxt
    hasBattleOrSquadTxt = battleOrSquadStatusTxt != ""
    onlineStatusColor
    squadLeaderTxt = colorize("@white", squadLeaderTxt)
    hasUnitList = false
  }

  if (squadStatus != squadMemberState.NOT_IN_SQUAD && squadStatus != squadMemberState.SQUAD_MEMBER_OFFLINE) {
    if (memberData) {
      let memberDataAirs = memberData?.crewAirs[memberData.country] ?? []
      let gm = getGameModeById(g_squad_manager.getLeaderGameModeId())
      let event = getGameModeEvent(gm)
      let ediff = events.getEDiffByEvent(event)
      view.unitList <- []
      view.hasUnitList = memberDataAirs.len() != 0

      if (memberData?.country != null && checkCountry(memberData.country, $"memberData of contact = {contact.uid}")
          && memberDataAirs.len() != 0) {
        if (!event?.multiSlot) {
          let unitName = memberData.selAirs[memberData.country]
          let unit = getAircraftByName(unitName)
          view.unitList.append({
            rank = format("%.1f", unit.getBattleRating(ediff))
            unit = unitName
            icon = getUnitClassIco(unit)
          })
        }
        else {
          foreach (id, unitName in memberDataAirs) {
            let unit = getAircraftByName(unitName)
            view.unitList.append({
              rank = format("%.1f", unit.getBattleRating(ediff))
              unit = unitName
              icon = getUnitClassIco(unit)
              even = id % 2 == 0
              isWideIco = ["ships", "helicopters", "boats"].contains(unit.unitType.armyId)
            })
          }
        }
        if (memberDataAirs.len() != 0) {
          let battleType = get_battle_type_by_ediff(ediff)
          let fonticon = getFontIconByBattleType(battleType)
          let difficulty = events.getEventDifficulty(event)
          let diffName = nbsp.join([ fonticon, difficulty.getLocName() ], true)
          view.hint <- $"{loc("shop/all_info_relevant_to_current_game_mode")}: {diffName}"
        }
      }
    }
  }

  let blk = handyman.renderCached("%gui/playerTooltip.tpl", view)
  let guiScene = obj.getScene()
  guiScene.replaceContentFromText(obj, blk, blk.len(), handler)
  obj.type="smallPadding"

  guiScene.applyPendingChanges(false)
  let contentContainer = obj.findObject("content-container")
  let [headerWidth] = obj.findObject("contact-header").getSize()
  contentContainer.width = headerWidth
}

return {
  getContact
}