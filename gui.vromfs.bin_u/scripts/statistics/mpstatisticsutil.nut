from "%scripts/dagui_natives.nut" import get_player_army_for_hud
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import locOrStrip

let { g_mplayer_param_type } = require("%scripts/mplayerParamType.nut")
let { g_team } = require("%scripts/teams.nut")
let { g_player_state } = require("%scripts/contacts/playerStateTypes.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { eventbus_subscribe } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoRoles.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { updateTopSquadScore, isShowSquad,
  getSquadInfoByMemberId, getTopSquadId } = require("%scripts/statistics/squadIcon.nut")
let { is_replay_playing } = require("replays")
let { get_game_mode, get_mp_local_team } = require("mission")
let { get_mission_difficulty_int, get_mp_session_info } = require("guiMission")
let { stripTags } = require("%sqstd/string.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk, get_ranks_blk } = require("blkGetters")
let { locCurrentMissionName } = require("%scripts/missions/missionsText.nut")
let { isInFlight } = require("gameplayBinding")
let { sessionLobbyStatus, getSessionLobbyTeam, getSessionLobbyPlayersInfo
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getRankByExp } = require("%scripts/ranks.nut")
let { isWorldWarEnabled } = require("%scripts/globalWorldWarScripts.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { isMemberInMySquadById } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { isEqualSquadId } = require("%scripts/squads/squadState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
require("%scripts/statistics/mpStatisticsPlayerTooltip.nut")

const ICON_SKIP_BG_COLORING = "image_in_progress_ico.svg"

let getKillsForAirBattle = @(player) player.kills
let getKillsForTankBattle = @(player) player.kills + player.groundKills
let getKillsForShipBattle = @(player) player.awardDamage

let eventNameBonusTypes = {
  air_arcade = {getKillsCount = getKillsForAirBattle, edgeName = "kills"}
  air_realistic = {getKillsCount = getKillsForAirBattle, edgeName = "kills"}
  tank_event_in_random_battles_arcade = {getKillsCount = getKillsForTankBattle, edgeName = "kills"}
  tank_random_battles_historical_base = {getKillsCount = getKillsForTankBattle, edgeName = "kills"}
  tank_event_in_random_battles_simulation = {getKillsCount = getKillsForTankBattle, edgeName = "kills"}
  tank_event_in_random_battles_simulation_1 = {getKillsCount = getKillsForTankBattle, edgeName = "kills"}
  ship_event_in_random_battles_arcade = {getKillsCount = getKillsForShipBattle, edgeName = "damage"}
  ship_event_in_random_battles_realistic = {getKillsCount = getKillsForShipBattle, edgeName = "damage"}
}

let cachedBonusTooltips = {}

let colsWithParamType = { aiTotalKills = true, assists = true, score = true, damageZone = true,
  raceFinishTime = true, raceLastCheckpoint = true, raceLastCheckpointTime = true,
  raceBestLapTime = true, missionAliveTime = true, kills = true, deaths = true
}

let colsWithCustomTooltip = { name = true, aircraft = true, unitIcon = true }
let colsWithWishlistContextMenu = hasFeature("Wishlist")
  ? { aircraft = true, unitIcon = true }
  : { }

function gui_start_mpstatscreen_(params = {}) {
  let isFromGame = params?.isFromGame ?? false
  handlersManager.loadHandler(gui_handlers.MPStatisticsModal,
    {
      backSceneParams = isFromGame ? null : handlersManager.getLastBaseHandlerStartParams(),
    }.__update(params))
}

eventbus_subscribe("gui_start_mpstatscreen_", gui_start_mpstatscreen_)


function getSkillBonusTooltipText(eventName) {
  if (cachedBonusTooltips?[eventName])
    return cachedBonusTooltips[eventName]

  let blk = get_ranks_blk()
  let bonuses = blk?.ExpSkillBonus[eventName]
  if (!bonuses)
    return ""
  let icon = loc("currency/researchPoints/sign/colored")

  local text = "".concat(loc("debrifieng/SkillBonusHintTitle"))
  foreach ( bonus in bonuses ) {
    let isBonusForKills = bonus?.kills != null
    let hintLoc = isBonusForKills ? "debrifieng/SkillBonusHintKills" : "debrifieng/SkillBonusHintDamage"
    let locData = loc(hintLoc, {req = isBonusForKills ? bonus.kills : bonus.damage, val = bonus.bonusPercent})
    text = "".concat( text, "\n\r", $"{locData}{icon}")
  }
  text = "".concat(text,"\n", loc("debrifieng/SkillBonusHintEnding"))
  text = colorize("commonTextColor", text)
  cachedBonusTooltips[eventName] <- text
  return text
}


function getWeaponTypeIcoByWeapon(airName, weapon) {
  let config = {
    bomb            = { icon = "", ratio = 0.375 }
    rocket          = { icon = "", ratio = 0.375 }
    torpedo         = { icon = "", ratio = 0.375 }
    additionalGuns  = { icon = "", ratio = 0.375 }
    mine            = { icon = "", ratio = 0.594 }
  }
  let air = getAircraftByName(airName)
  if (!air)
    return config

  foreach (w in air.getWeapons()) {
    if (w.name != weapon)
      continue

    let isShip = air.isShipOrBoat()
    config.bomb = {
      icon = !w.bomb ? ""
        : isShip ? "#ui/gameuiskin#weap_naval_bomb.svg"
        : "#ui/gameuiskin#weap_bomb.svg"
      ratio = isShip ? 0.594 : 0.375
    }
    config.rocket.icon = w.rocket ? "#ui/gameuiskin#weap_missile.svg" : ""
    config.torpedo.icon = w.torpedo ? "#ui/gameuiskin#weap_torpedo.svg" : ""
    config.additionalGuns.icon = w.additionalGuns ? "#ui/gameuiskin#weap_pod.svg" : ""
    config.mine.icon = w.hasMines ? "#ui/gameuiskin#weap_mine.svg" : ""
    break
  }
  return config
}

function get_mp_country_by_team(team) {
  let info = get_mp_session_info()
  if (!info)
    return ""
  if (team == 1 && ("alliesCountry" in info))
    return $"country_{info.alliesCountry}"
  if (team == 2 && ("axisCountry" in info))
    return $"country_{info.axisCountry}"
  return "country_0"
}

function guiStartMPStatScreen() {
  let params = { isFromGame = false }
  gui_start_mpstatscreen_(params)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mpstatscreen_", params })
}

function guiStartMPStatScreenFromGame(_ = {}) {
  let params = { isFromGame = true }
  gui_start_mpstatscreen_(params)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mpstatscreen_", params })
}

eventbus_subscribe("gui_start_mpstatscreen_from_game", guiStartMPStatScreenFromGame) 
eventbus_subscribe("gui_start_flight_menu_stat", guiStartMPStatScreenFromGame) 

local time_to_kick_show_timer = null
local time_to_kick_show_alert = null
local in_battle_time_to_kick_show_timer = null
local in_battle_time_to_kick_show_alert = null

function get_time_to_kick_show_timer() {
  if (time_to_kick_show_timer == null) {
    time_to_kick_show_timer = get_game_settings_blk()?.time_to_kick.show_timer_threshold ?? 30
  }
  return time_to_kick_show_timer
}
let set_time_to_kick_show_timer = @(v) time_to_kick_show_alert = v

function get_time_to_kick_show_alert() {
  if (time_to_kick_show_alert == null) {
    time_to_kick_show_alert = get_game_settings_blk()?.time_to_kick.show_alert_threshold ?? 15
  }
  return time_to_kick_show_alert
}

let set_time_to_kick_show_alert = @(v) time_to_kick_show_alert = v

function get_in_battle_time_to_kick_show_timer() {
  if (in_battle_time_to_kick_show_timer == null) {
    in_battle_time_to_kick_show_timer = get_game_settings_blk()?.time_to_kick.in_battle_show_timer_threshold ?? 150
  }
  return in_battle_time_to_kick_show_timer
}

let set_in_battle_time_to_kick_show_timer = @(v) in_battle_time_to_kick_show_timer = v

function get_in_battle_time_to_kick_show_alert() {
  if (in_battle_time_to_kick_show_alert == null) {
    in_battle_time_to_kick_show_alert = get_game_settings_blk()?.time_to_kick.in_battle_show_alert_threshold ?? 50
  }
  return in_battle_time_to_kick_show_alert
}

let set_in_battle_time_to_kick_show_alert = @(v) in_battle_time_to_kick_show_alert = v

function getLocalTeamForMpStats(team = null) {
  return (team ?? get_mp_local_team()) != g_team.B.code ? g_team.A.code : g_team.B.code
}

function createExpSkillBonusIcon(tooltipFunction) {
  return "".concat("img{ id:t='exp_skill_bonus_icon' not-input-transparent:t='yes'; tooltip:t='$tooltipObj'; size:t='@tableIcoSize, @tableIcoSize';",
    "top:t='0.5ph-0.5h'; position:t='relative';background-image:t='';",
    "background-svg-size:t='@tableIcoSize, @tableIcoSize'; left:t='0'; margin:t='2@dp, 0'; tooltipObj{", $"on_tooltip_open:t='{tooltipFunction}';",
    " display:t='hide'}}"
  )
}

function createCellCustomTooltip(tooltipId) {
  return format(@"tooltip:t='$tooltipObj'; tooltipObj { id:t='%s';
    on_tooltip_open:t='onGenericTooltipOpen'; on_tooltip_close:t='onTooltipObjClose';
    display:t='hide' }", tooltipId)
}

function buildMpTable(table, markupData, hdr, numRows = 1, params = {}) {
  if (numRows <= 0)
    return ""

  let numTblRows = table.len()
  let isHeader    = markupData?.is_header ?? false
  let trSize      = markupData?.tr_size   ?? "pw, @baseTrHeight"
  let isRowInvert = markupData?.invert    ?? false
  let colorTeam   = markupData?.colorTeam ?? "blue"
  let trOnHover   = markupData?.trOnHover

  let markup = markupData.columns

  if (isRowInvert) {
    hdr = clone hdr
    hdr.reverse()
  }

  let data = []
  for (local i = 0; i < numRows; i++) {
    let isEmpty = i >= numTblRows
    let trData = [format("even:t='%s'; ", (i % 2 == 0) ? "yes" : "no")]
    let trAdd = [isEmpty ? "inactive:t='yes'; " : ""]
    if (!u.isEmpty(trOnHover))
      trAdd.append($"rowIdx='{i}'; on_hover:t='{trOnHover}'; on_unhover:t='{trOnHover}';")

    for (local j = 0; j < hdr.len(); ++j) {
      local item = ""
      local tdData = ""
      let widthAdd = ((j == 0) || (j == (hdr.len() - 1))) ? "+@tablePad" : ""
      let textPadding = "style:t='padding:@tablePad,0;'; "
      local customTooltipId = null

      if (!isEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] in colsWithCustomTooltip)
        customTooltipId = $"{hdr[j]}_tooltip"

      if (hdr[j] == "hasPassword") {
        let icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData = "".concat("size:t='ph", widthAdd, " ,ph';",
          "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';",
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='", isEmpty ? "" : icon, "'; }")
      }
      else if (hdr[j] == "team") {
        let teamText = "teamImg{ text { halign:t='center'}} "
        tdData = "".concat("size:t='ph", widthAdd, ",ph'; css-hier-invalidate:t='yes'; team:t=''; ", teamText)
      }
      else if (hdr[j] == "country" || hdr[j] == "teamCountry") {
        local country = ""
        if (hdr[j] == "country")
          country = item
        else if (!isEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        local icon = ""
        if (!isEmpty && country != "")
          icon = getCountryIcon(country)
        tdData = format("".concat("size:t='ph%s,ph';",
          "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';",
          "background-image:t='%s'; background-svg-size:t='@cIco, @cIco';",
          "}"), widthAdd, icon)
      }
      else if (hdr[j] == "status") {
        tdData = format("size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico' } ", widthAdd)
      }
      else if (hdr[j] == "name") {
        local nameText = item
        if (!isEmpty && !isHeader && !table[i].isBot)
          nameText = getPlayerFullName(getPlayerName(nameText), table[i].clanTag)

        nameText = stripTags(nameText)
        let nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        let nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData = format("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s';" +
          "pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s",
          nameWidth, "textareaNoTab", nameAlign, nameText, textPadding
        )
        if (!isEmpty) {
          
          if (table[i]?.isLocal)
            trAdd.append("mainPlayer:t = 'yes';")
          else if (table[i]?.isInHeroSquad || isMemberInMySquadById(table[i]?.userId.tointeger()))
            trAdd.append("inMySquad:t = 'yes';")
          if (("spectator" in table[i]) && table[i].spectator)
            trAdd.append("spectator:t = 'yes';")
        }
      }
      else if (hdr[j] == "unitIcon") {
        
        let images = params?.canHasBonusIcon ? [createExpSkillBonusIcon("onSkillBonusTooltip")] : []

        foreach (id, _weap in getWeaponTypeIcoByWeapon("", ""))
          images.append(format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-svg-size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0' }", id))

        images.append("div{ size:t='@tableIcoSize,@tableIcoSize' img { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-image:t=''; background-repeat:t='aspect-ratio'; shopItemType:t=''; }}")

        if (isRowInvert)
          images.reverse()
        let cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        let divPos = isRowInvert ? "0" : "pw-w"
        tdData = format("width:t='%s'; tdiv { pos:t='%s, ph/2-h/2'; position:t='absolute'; %s } ", cellWidth, divPos, "".join(images, true))
      }
      else if (hdr[j] == "rank") {
        local prestigeImg = "";
        local rankTxt = ""
        if (!isEmpty && ("exp" in table[i]) && ("prestige" in table[i])) {
          rankTxt = getRankByExp(table[i].exp).tostring()
          prestigeImg = $"#ui/gameuiskin#prestige{table[i].prestige}"
        }
        let rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        let prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        let cell = isRowInvert ? $"{prestigeItem}{rankItem}" : $"{rankItem}{prestigeItem}"
        tdData = format("".concat("width:t='2.2@rows16height%s'; tdiv { pos:t='%s, 0.5(ph-h)'; position:t='absolute'; ", cell, " } "),
          widthAdd, isRowInvert ? "0" : "pw-w-1", "0", "0.003sh")
      }
      else if (hdr[j] == "rowNo") {
        let tdProp = []
        if (hdr[j] in markup)
          tdProp.append(format("width:t='%s'", getTblValue("width", markup[hdr[j]], "")))

        trAdd.append("winnerPlace:t='none';")
        tdData = format("%s activeText { text:t = '%i'; halign:t='center'} ", "".join(tdProp), i + 1)
      }
      else if (hdr[j] == "place") {
        let width = $"width:t='{markup[hdr[j]]?.width ?? 1}'; "
        tdData = format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (hdr[j] in colsWithParamType) {
        let txt = isEmpty ? "" : g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData = format("activeText { text:t='%s' halign:t='center' } ", txt)
        let width = getTblValue("width", getTblValue(hdr[j], markup, {}), "")
        if (width != "")
          tdData = "".concat(tdData, format("width:t='%s'; ", width))
      }
      else if (hdr[j] == "numPlayers") {
        let curWidth = ((hdr[j] in markup) && ("width" in markup[hdr[j]])) ? markup[hdr[j]].width : "0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isEmpty && "numPlayersTotal" in table[i]) {
          let maxVal = table[i].numPlayersTotal
          txt = $"{txt}/{maxVal}"
          if (item >= maxVal)
            txtParams = $"{txtParams}overlayTextColor:t='warning';"
        }
        tdData = "".concat("width:t='", curWidth, "'; activeText { text:t = '", txt, "'; ", txtParams, " } ")
      }
      else {
        local tdProp = textPadding
        local textType = "activeText"
        let text = locOrStrip(item.tostring())
        local halign = "center"
        local pareText = true
        local imageBg = ""

        if (hdr[j] in markup) {
          if ("width" in markup[hdr[j]])
            tdProp = "".concat(tdProp, "width:t='", markup[hdr[j]].width, "'; ")
          if ("textDiv" in markup[hdr[j]])
            textType = markup[hdr[j]].textDiv
          if ("halign" in markup[hdr[j]])
            halign =  markup[hdr[j]].halign
          if ("pareText" in markup[hdr[j]])
            pareText =  markup[hdr[j]].pareText
          if ("image" in markup[hdr[j]])
            imageBg = format("".concat(" team:t='%s'; ", "teamImg {", "css-hier-invalidate:t='yes'; ",
                "id:t='%s';", "background-image:t='%s';", "display:t='%s'; "),
              colorTeam, $"icon_{hdr[j]}", markup[hdr[j]].image, isEmpty ? "hide" : "show"
            )
        }
        let textParams = format("halign:t='%s'; ", halign)

        tdData = format("".concat("%s {", "id:t='%s';", "text:t = '%s';",
            "max-width:t='pw';", "pare-text:t='%s'; ", "%s}"),
          $"{tdProp}{imageBg}{textType}", $"txt_{hdr[j]}", text, pareText ? "yes" : "no",
          "".concat(textParams, (imageBg == "") ? "" : "}")
        )
      }

      trData.append("td { id:t='td_", hdr[j], "'; ")
      if (customTooltipId)
        trData.append(createCellCustomTooltip(customTooltipId))
      if (hdr[j] in colsWithWishlistContextMenu)
        trData.append("cursor:t='normal'; isNavInContainerBtn:t='no'; contextMenu:t='no'; ")
      if (j == 0)
        trData.append("padding-left:t='@tablePad'; ")
      if (j > 0)
        trData.append("cellType:t = 'border'; ")
      if (j == (hdr.len() - 1))
        trData.append("padding-right:t='@tablePad'; ")
      trData.append(tdData, " }")
    }

    data.append("".concat("tr {size:t = '", trSize, "'; ", "".join(trAdd), "".join(trData),
      " text-valign:t='center'; css-hier-invalidate:t='all'; }"))
  }

  return "\n".join(data)
}

function updateTeamCssLabel(nestObj, customPlayerTeam = null) {
  if (!checkObj(nestObj))
    return
  let teamCode = (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) ? getSessionLobbyTeam()
    : (customPlayerTeam ?? getLocalTeamForMpStats())
  nestObj.playerTeam = g_team.getTeamByCode(teamCode).cssLabel
}


function getExpBonusIndexForPlayer(player, expSkillBonuses, skillBonusType) {
  if (expSkillBonuses == null || skillBonusType == null)
    return 0
  let { getKillsCount, edgeName } = skillBonusType
  let killsCount = getKillsCount(player)
  let blockCount = expSkillBonuses.blockCount()
  for (local idx = 0; idx < blockCount; idx++) {
    let bonus = expSkillBonuses.getBlock(idx)
    let edge = bonus?[edgeName]
    if (edge == null || edge > killsCount)
      return idx
  }
  return blockCount
}

function getUnitCardTooltipId(player) {
  let { aircraftName = "", isSpectator = false, isLocal = false } = player
  if (aircraftName == "" || aircraftName == "dummy_plane" || isSpectator)
    return null
  return getTooltipType("UNIT").getTooltipId(aircraftName,
    { showLocalState = isLocal, showInFlightInfo = isLocal })
}

function setMpTable(obj_tbl, table, params = {}) {
  let numTblRows = table.len()
  let realTblRows = obj_tbl.childrenCount()
  let numRows = max(numTblRows, realTblRows)
  if (numRows <= 0)
    return

  let { showUnitsInfo = true, continueRowNum = 0, numberOfWinningPlaces = -1,
    isDebriefing = false } = params
  let playersInfo = params?.playersInfo ?? getSessionLobbyPlayersInfo()
  let needColorizeNotInGame = isInFlight()
  let isReplay = is_replay_playing()
  let isAlly = obj_tbl?.team == "blue"

  updateTopSquadScore(table)
  for (local i = 0; i < numRows; i++) {
    local objTr = null
    if (realTblRows <= i) {
      objTr = obj_tbl.getChild(realTblRows - 1).getClone(obj_tbl, params?.handler)
      if (objTr?.rowIdx != null)
        objTr.rowIdx = i.tostring()
      objTr.even = (i % 2 == 0) ? "yes" : "no"
      objTr.selected = "no"
    }
    else
      objTr = obj_tbl.getChild(i)

    let isEmpty = i >= numTblRows
    objTr.inactive = isEmpty ? "yes" : "no"
    objTr.show(!isEmpty)
    if (isEmpty)
      continue

    let player = table[i]
    local isInGame = true
    if (needColorizeNotInGame) {
      let state = table[i].state
      isInGame = state == PLAYER_IN_FLIGHT || state == PLAYER_IN_RESPAWN
      objTr.inGame = isInGame ? "yes" : "no"
    }

    let unitCardTooltipId = showUnitsInfo ? getUnitCardTooltipId(player) : null

    let totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++) {
      let objTd = objTr.getChild(idx)
      let id = objTd?.id
      if (!id || id.len() < 4 || id.slice(0, 3) != "td_")
        continue

      let hdr = id.slice(3)
      local item = ""

      if (hdr in table[i])
        item = table[i][hdr]

      if (isReplay) {
        table[i].isLocal = spectatorWatchedHero.id == table[i].id
        table[i].isInHeroSquad = isEqualSquadId(spectatorWatchedHero.squadId,
          table[i]?.squadId)
      }

      if (hdr in colsWithWishlistContextMenu) {
        let hasUnitCard = !!unitCardTooltipId
        objTd.cursor = hasUnitCard ? "context-menu" : "normal"
        objTd.isNavInContainerBtn = hasUnitCard ? "yes" : "no"
        objTd.contextMenu = hasUnitCard ? "wishlist" : "no"
      }

      if (hdr == "team") {
        local teamText = ""
        local teamStyle = ""
        if (item == 1) {
          teamText = "A"
          teamStyle = "a"
        }
        else if ( item == 2) {
          teamText = "B"
          teamStyle = "b"
        }
        else {
          teamText = "?"
          teamStyle = ""
        }
        objTd.getChild(0).setValue(teamText)
        objTd["team"] = teamStyle
      }
      else if (hdr == "country" || hdr == "teamCountry") {
        local country = ""
        if (hdr == "country")
          country = item
        else if ("team" in table[i])
            country = get_mp_country_by_team(table[i].team)

        let objImg = objTd.getChild(0)
        local icon = ""
        if (country != "")
          icon = getCountryIcon(country)
        objImg["background-image"] = icon
      }
      else if (hdr == "status") {
        let objReady = objTd.findObject("ready-ico")
        let playerState = g_player_state.getStateByPlayerInfo(table[i])
        if (objReady?.isValid()) {
          objReady["background-image"] = playerState.getIcon(table[i])
          objReady["background-color"] = playerState.getIconColor()
        }
        let desc = playerState.getText(table[i])
        objTd.tooltip = (desc != "") ? loc("ui/colon").concat(loc("multiplayer/state"), desc) : ""
      }
      else if (hdr == "name") {
        local nameText = item
        if (!player.isBot)
          nameText = getPlayerFullName(getPlayerName(nameText), table[i].clanTag)

        if (table[i]?.invitedName && table[i].invitedName != item) {
          local color = ""
          if (obj_tbl?.team) {
            if (obj_tbl.team == "red")
              color = "teamRedInactiveColor"
            else if (obj_tbl.team == "blue")
              color = "teamBlueInactiveColor"
          }

          local playerName = colorize(color, getPlayerName(table[i].invitedName))
          nameText = $"{getPlayerName(nameText)}... {playerName}"
        }

        let objName = objTd.findObject("name-text")
        if (checkObj(objName))
         objName.setValue(nameText)

        let objDlcImg = objTd.findObject("dlc-ico")
        if (checkObj(objDlcImg))
          objDlcImg.show(false)
        let isLocal = table[i].isLocal
        
        let isInHeroSquad = table[i]?.isInHeroSquad || isMemberInMySquadById(table[i]?.userId.tointeger())
        objTr.mainPlayer = isLocal ? "yes" : "no"
        objTr.inMySquad  = isInHeroSquad ? "yes" : "no"
        objTr.spectator = table[i]?.spectator ? "yes" : "no"

        let userIdInt = player.userId.tointeger()
        let playerInfo = playersInfo?[player.userId] ?? playersInfo?[userIdInt]
        if (!player.isBot || (isReplay && userIdInt > 0)) {
          let tooltipId = getTooltipType("MP_STAT_PLAYER").getTooltipId(player, {
            playerInfo, isAlly, isDebriefing
          })
          objTd.findObject("name_tooltip").tooltipId = tooltipId
          objTd.tooltip = "$tooltipObj"
        } else {
          objTd.tooltip = nameText
        }
      }
      else if (hdr == "unitIcon") {
        local unitIco = ""
        local unitIcoColorType = ""
        local unitId = ""
        local weapon = ""

        if (isInFlight() && !isInGame)
          unitIco = g_player_state.HAS_LEAVED_GAME.getIcon(player)
        else if (player?.isDead)
          unitIco = (player?.spectator) ? "#ui/gameuiskin#player_spectator.svg" : "#ui/gameuiskin#dead.svg"
        else if (showUnitsInfo && ("aircraftName" in player)) {
          unitId = player.aircraftName
          unitIco = getUnitClassIco(unitId)
          unitIcoColorType = getUnitRole(unitId)
          weapon = player?.weapon ?? ""
        }

        local obj = objTd.findObject("unit-ico")
        if (checkObj(obj)) {
          obj["background-image"] = unitIco
          obj["shopItemType"] = unitIcoColorType
          obj["skipBgColor"] = unitIco.endswith(ICON_SKIP_BG_COLORING) ? "yes" : "no"
        }

        if (params?.canHasBonusIcon) {
          let roomEventName = params?.roomEventName ?? ""
          let expSkillBonuses = get_ranks_blk()?.ExpSkillBonus[roomEventName]
          let skillBonusType = eventNameBonusTypes?[roomEventName]

          let bonusIndex = getExpBonusIndexForPlayer(player, expSkillBonuses, skillBonusType)
          let nameIcon = objTd.findObject("exp_skill_bonus_icon")
          if (checkObj(nameIcon)) {
            nameIcon["background-image"] = bonusIndex > 0 ? $"#ui/gameuiskin#skill_bonus_level_{bonusIndex}.svg" : ""
          }
        }

        foreach (iconId, weap in getWeaponTypeIcoByWeapon(unitId, weapon)) {
          obj = objTd.findObject($"{iconId}-ico")
          if (checkObj(obj)) {
            let iconSize = $"{weap.ratio}@tableIcoSize,@tableIcoSize"
            obj.size = iconSize
            obj["background-image"] = weap.icon
            obj["background-svg-size"] = iconSize
          }
        }
        objTd.tooltip = unitCardTooltipId ? "$tooltipObj" : ""
        if (unitCardTooltipId)
          objTd.findObject("unitIcon_tooltip").tooltipId = unitCardTooltipId
      }
      else if (hdr == "aircraft") {
        let objText = objTd.findObject("txt_aircraft")
        if (checkObj(objText)) {
          local text = ""
          local tooltip = ""
          if (getTblValue("spectator", table[i], false)) {
            text = loc("mainmenu/btnReferee")
            tooltip = loc("multiplayer/state/player_referee")
          }
          else {
            let unitId = getTblValue("aircraftName", table[i], "")
            text = (unitId != "") ? loc(getUnitName(unitId, true)) : "..."
            tooltip = (unitId != "") ? loc(getUnitName(unitId, false)) : ""
          }
          objText.setValue(text)
          objTd.tooltip = unitCardTooltipId ? "$tooltipObj" : tooltip
          if (unitCardTooltipId)
            objTd.findObject("aircraft_tooltip").tooltipId = unitCardTooltipId
        }
      }
      else if (hdr == "rowNo") {
        let tablePos = i + 1
        let pos = tablePos + continueRowNum
        objTd.getChild(0).setValue(pos.tostring())
        local winPlace = "none"
        if (numberOfWinningPlaces > 0 && getTblValue("raceLastCheckpoint", table[i], 0) > 0) {
          if (tablePos == 1)
            winPlace = "1st"
          else if (tablePos <= numberOfWinningPlaces)
            winPlace = "2nd"
        }
        objTr.winnerPlace = winPlace
      }
      else if (hdr == "place") {
        objTd.getChild(0).setValue(item)
      }
      else if (hdr in colsWithParamType) {
        let paramType = g_mplayer_param_type.getTypeById(hdr)
        let txt = paramType ? paramType.printFunc(item, table[i]) : ""
        let objText = objTd.getChild(0)
        objText.setValue(txt)
        objTd.tooltip = paramType ? paramType.getTooltip(item, table[i], txt) : ""
      }
      else if (hdr == "numPlayers") {
        local txt = item.tostring()
        if ("numPlayersTotal" in table[i])
          txt = "".concat(txt, "/", table[i].numPlayersTotal)
        objTd.getChild(0).setValue(txt)
      }
      else if (hdr == "squad") {
        let squadInfo = isShowSquad() ? getSquadInfoByMemberId(table[i]?.userId.tointeger()) : null
        let squadId = getTblValue("squadId", squadInfo, INVALID_SQUAD_ID)
        let labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        let needSquadIcon = labelSquad != ""
        let squadScore = needSquadIcon ? getTblValue("squadScore", table[i], 0) : 0
        let isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == getTopSquadId(squadInfo.teamId)

        let cellText = objTd.findObject($"txt_{hdr}")
        if (checkObj(cellText))
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")

        let cellIcon = objTd.findObject($"icon_{hdr}")
        if (checkObj(cellIcon)) {
          cellIcon.show(needSquadIcon)
          if (needSquadIcon) {
            cellIcon["iconSquad"] = squadInfo.autoSquad ? "autosquad" : "squad"
            cellIcon["topSquad"] = isTopSquad ? "yes" : "no"
            cellIcon["tooltip"] = "".concat(format("%s %s%s", loc("options/chat_messages_squad"), loc("ui/number_sign", "#"), labelSquad),
              "\n", loc("profile/awards"), loc("ui/colon"), squadScore,
              (isTopSquad ? $"\n{loc("streaks/squad_best")}" : ""))

            if (isReplay)
              objTd.team = squadInfo.teamId == get_player_army_for_hud() ? "blue" : "red"
          }
        }
      }
      else {
        local txt = item.tostring()
        if (txt.len() > 0 && txt[0] == '#')
          txt = loc(txt.slice(1))
        let objText = objTd.findObject($"txt_{hdr}")
        if (objText)
          objText.setValue(txt)

        objTd.tooltip = g_mplayer_param_type.getTypeById(hdr).getDefTooltip(txt)
      }
    }
  }
}

function getCurMpTitle() {
  let text = []

  if (getCurMissionRules().isWorldWar && isWorldWarEnabled()) {
    text.append(::g_world_war.getCurMissionWWBattleName())
  }
  else {
    let gm = get_game_mode()
    if (gm == GM_DOMINATION) {
      let diffCode = get_mission_difficulty_int()
      text.append(g_difficulty.getDifficultyByDiffCode(diffCode).getLocName())
    }
    else if (gm == GM_SKIRMISH)
      text.append(loc("multiplayer/skirmishMode"))
    else if (gm == GM_CAMPAIGN)
      text.append(loc("mainmenu/btnCampaign"))
    else if (gm == GM_SINGLE_MISSION)
      text.append(loc("mainmenu/btnCoop"))
    else if (gm == GM_DYNAMIC)
      text.append(loc("mainmenu/btnDynamic"))
    else if (gm == GM_BUILDER)
      text.append(loc("mainmenu/btnBuilder"))
    
  }

  text.append(locCurrentMissionName())
  return loc("ui/comma").join(text, true)
}

function countWidthForMpTable(objTbl, markup) {
  let guiScene = objTbl.getScene()
  local usedWidth = 0
  local relWidthTotal = 0.0
  foreach (_id, col in markup) {
    if ("relWidth" in col)
      relWidthTotal += col.relWidth
    else if ("width" in col) {
      let width = guiScene.calcString(col.width, objTbl)
      col.width = width.tostring()
      usedWidth += width
    }
  }

  local freeWidth = objTbl.getSize()[0] - usedWidth
  foreach (_id, col in markup) {
    if (relWidthTotal > 0 && ("relWidth" in col)) {
      let width = (freeWidth * col.relWidth / relWidthTotal).tointeger()
      col.width <- width.tostring()
      freeWidth -= width
      relWidthTotal -= col.relWidth
      col.$rawdelete("relWidth")
    }
  }
}

addListenersWithoutEnv({
  GameLocalizationChanged = function (_p) {
    cachedBonusTooltips.clear()
  }
})

return {
  guiStartMPStatScreen
  guiStartMPStatScreenFromGame
  getWeaponTypeIcoByWeapon
  getSkillBonusTooltipText
  set_time_to_kick_show_alert
  get_time_to_kick_show_alert
  set_in_battle_time_to_kick_show_alert
  get_in_battle_time_to_kick_show_alert
  get_in_battle_time_to_kick_show_timer
  set_in_battle_time_to_kick_show_timer
  get_time_to_kick_show_timer
  set_time_to_kick_show_timer
  getCurMpTitle
  setMpTable
  getLocalTeamForMpStats
  buildMpTable
  updateTeamCssLabel
  countWidthForMpTable
}