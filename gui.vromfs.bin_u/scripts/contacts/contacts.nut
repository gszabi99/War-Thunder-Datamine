import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/events/eventsState.nut" import getEventDifficulty
from "%scripts/events/eventTeamsInfo.nut" import getEDiffByEvent
from "%scripts/squads/squadState.nut" import getLeaderGameModeId, getMemberData, getPlayerStatusInMySquad
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/user/usersInfoManager.nut" import requestUsersInfo, getUserInfo
from "%scripts/contacts/customNicknames.nut" import getCustomNick
from "%scripts/difficulty.nut" import get_battle_type_by_ediff
from "%scripts/gameModes/gameModeManagerState.nut" import getGameModeById, getGameModeEvent
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco, getFontIconByBattleType
from "%scripts/unit/unitMrankSelectionState.nut" import getEffectiveMrank
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%scripts/user/presenceType.nut" import getByPresenceParams
from "%scripts/user/clanName.nut" import getMyClanTag
from "string" import format
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState
from "%scripts/shop/shopCountriesList.nut" import checkCountry
from "%scripts/user/profileAppearance.nut" import getProfileAvatarFrameCfg

let { contactsPlayers } = require("%scripts/contacts/contactsListState.nut")
let { missed_contacts_data } = require("%scripts/contacts/contactsInfo.nut")
let Contact = require("%scripts/contacts/contact.nut")

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

function fillContactTooltip(obj, contact, handler) {
  let customNick = getCustomNick(contact)
  local playerName = customNick == null
    ? contact.getName()
    : $"{contact.getName()}{loc("ui/parentheses/space", { text = customNick })}"
  let clanTag = contact.isMe()
    ? getMyClanTag()
    : contact.clanTag

  let wtName = contact.steamName == null || contact.name == ""
    ? ""
    : loc("war_thunder_nickname", { name = getPlayerName(contact.name) })

  let squadStatus = getPlayerStatusInMySquad(contact.uid)
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

  let memberData = getMemberData(contact.uid)
  let presenceStatus = memberData?.presenceStatus
  let presenceType = getByPresenceParams(presenceStatus)
  let battleOrSquadStatusTxt = getContactTooltipBattleOrSquadStatusTxt(contact, squadStatus, { presenceType, presenceStatus })
  let onlineStatusColor = contact.onlinePresence.getColorInTooltip()
  let { frame = "" } = userInfo
  let { frameImagePath, framesCount } = getProfileAvatarFrameCfg(frame)

  let view = {
    name = colorize("@white", playerName)
    clanTag = clanTag ? colorize("@white", clanTag) : null
    wtName = colorize("@white", wtName)
    title = colorize("@white", title)
    icon = contact.steamAvatar ?? $"#ui/images/avatars/{contact.pilotIcon}.avif"
    headerBackground
    frameImagePath
    framesCount
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
      let gm = getGameModeById(getLeaderGameModeId())
      let event = getGameModeEvent(gm)
      let ediff = getEDiffByEvent(event)
      view.unitList <- []
      view.hasUnitList = memberDataAirs.len() != 0

      if (memberData?.country != null && checkCountry(memberData.country, $"memberData of contact = {contact.uid}")
          && memberDataAirs.len() != 0) {
        let getUnitBattleRatingText = @(unit) format("%.1f",
          calcBattleRatingFromRank(getEffectiveMrank(unit, ediff, memberData.mrankDeltaByUnit?[unit.name] ?? 0)))
        if (!event?.multiSlot) {
          let unitName = memberData.selAirs[memberData.country]
          let unit = getAircraftByName(unitName)
          view.unitList.append({
            rank = getUnitBattleRatingText(unit)
            unit = unitName
            icon = getUnitClassIco(unit)
          })
        }
        else {
          foreach (id, unitName in memberDataAirs) {
            let unit = getAircraftByName(unitName)
            view.unitList.append({
              rank = getUnitBattleRatingText(unit)
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
          let difficulty = getEventDifficulty(event)
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

return freeze({
  getContact
  fillContactTooltip
})