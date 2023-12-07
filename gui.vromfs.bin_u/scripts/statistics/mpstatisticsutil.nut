//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { WEAPON_TAG } = require("%scripts/weaponry/weaponryInfo.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { updateTopSquadScore, getSquadInfo, isShowSquad,
  getSquadInfoByMemberId, getTopSquadId } = require("%scripts/statistics/squadIcon.nut")
let { is_replay_playing } = require("replays")
let { get_game_mode } = require("mission")
let { get_mission_difficulty_int, get_mission_difficulty, get_mp_session_info } = require("guiMission")
let { stripTags } = require("%sqstd/string.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk, get_ranks_blk } = require("blkGetters")
let { locCurrentMissionName } = require("%scripts/missions/missionsUtils.nut")
let { isInFlight } = require("gameplayBinding")
let { sessionLobbyStatus } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")

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


::gui_start_mpstatscreen_ <- function gui_start_mpstatscreen_(params = {}) { // used from native code
  let isFromGame = params?.isFromGame ?? false
  let handler = handlersManager.loadHandler(gui_handlers.MPStatisticsModal,
    {
      backSceneParams = isFromGame ? null : handlersManager.getLastBaseHandlerStartParams(),
    }.__update(params))

  if (isFromGame)
    ::statscreen_handler = handler
}


let function getSkillBonusTooltipText(eventName) {
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
  cachedBonusTooltips[eventName] <- text
  return text
}


let function getWeaponTypeIcoByWeapon(airName, weapon) {
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

let function sort_units_for_br_tooltip(u1, u2) {
  if (u1.rating != u2.rating)
    return u1.rating > u2.rating ? -1 : 1
  if (u1.rankUnused != u2.rankUnused)
    return u1.rankUnused ? 1 : -1
  return 0
}

let function get_mp_country_by_team(team) {
  let info = get_mp_session_info()
  if (!info)
    return ""
  if (team == 1 && ("alliesCountry" in info))
    return "country_" + info.alliesCountry
  if (team == 2 && ("axisCountry" in info))
    return "country_" + info.axisCountry
  return "country_0"
}

let function guiStartMPStatScreen() {
  let params = { isFromGame = false }
  ::gui_start_mpstatscreen_(params)
  handlersManager.setLastBaseHandlerStartParams({ globalFunctionName = "gui_start_mpstatscreen_", params })
}

let function guiStartMPStatScreenFromGame() {
  let params = { isFromGame = true }
  ::gui_start_mpstatscreen_(params)
  handlersManager.setLastBaseHandlerStartParams({ globalFunctionName = "gui_start_mpstatscreen_", params })
}

::gui_start_mpstatscreen_from_game <- @() guiStartMPStatScreenFromGame() // used from native code
::gui_start_flight_menu_stat <- @() guiStartMPStatScreenFromGame() // used from native code

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

//!!!FIX Rebuild global functions below to local

::get_local_team_for_mpstats <- function get_local_team_for_mpstats(team = null) {
  return (team ?? ::get_mp_local_team()) != ::g_team.B.code ? ::g_team.A.code : ::g_team.B.code
}


let function createExpSkillBonusIcon(tooltipFunction) {
  return "".concat("img{ id:t='exp_skill_bonus_icon' not-input-transparent:t='yes'; tooltip:t='$tooltipObj'; size:t='@tableIcoSize, @tableIcoSize';",
    "top:t='0.5ph-0.5h'; position:t='relative';background-image:t='';",
    "background-svg-size:t='@tableIcoSize, @tableIcoSize'; left:t='0'; margin:t='2@dp, 0'; tooltipObj{", $"on_tooltip_open:t='{tooltipFunction}';",
    " display:t='hide'}}"
  )
}


::build_mp_table <- function build_mp_table(table, markupData, hdr, numRows = 1, params = {}) {
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

  local data = ""
  for (local i = 0; i < numRows; i++) {
    let isEmpty = i >= numTblRows
    local trData = format("even:t='%s'; ", (i % 2 == 0) ? "yes" : "no")
    local trAdd = isEmpty ? "inactive:t='yes'; " : ""
    if (!u.isEmpty(trOnHover))
      trAdd = "".concat(trAdd, $"rowIdx='{i}'; on_hover:t='{trOnHover}'; on_unhover:t='{trOnHover}';")

    for (local j = 0; j < hdr.len(); ++j) {
      local item = ""
      local tdData = ""
      let widthAdd = ((j == 0) || (j == (hdr.len() - 1))) ? "+@tablePad" : ""
      local textPadding = "style:t='padding:@tablePad,0;'; "

      if (!isEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] == "hasPassword") {
        let icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData += "size:t='ph" + widthAdd + " ,ph';"  +
          ("img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';" +
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='" + (isEmpty ? "" : icon) + "'; }")
      }
      else if (hdr[j] == "team") {
        let teamText = "teamImg{ text { halign:t='center'}} "
        tdData += "size:t='ph" + widthAdd + ",ph'; css-hier-invalidate:t='yes'; team:t=''; " + teamText
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
        tdData += format("size:t='ph%s,ph';"
          + "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';"
          +   "background-image:t='%s'; background-svg-size:t='@cIco, @cIco';"
          + "}",
          widthAdd, icon)
      }
      else if (hdr[j] == "status") {
        tdData = format("size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico' } ", widthAdd)
      }
      else if (hdr[j] == "name") {
        local nameText = item
        if (!isEmpty && !isHeader && !table[i].isBot)
          nameText = ::g_contacts.getPlayerFullName(getPlayerName(nameText), table[i].clanTag)

        nameText = stripTags(nameText)
        let nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        let nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData += format ("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s';" +
          "pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s",
          nameWidth, "textareaNoTab", nameAlign, nameText, textPadding
        )
        if (!isEmpty) {
          //isInMySquad check fixes lag of first 4 seconds, when code don't know about player in my squad.
          if (table[i]?.isLocal)
            trAdd += "mainPlayer:t = 'yes';"
          else if (table[i]?.isInHeroSquad || ::SessionLobby.isMemberInMySquadById(table[i]?.userId.tointeger()))
            trAdd += "inMySquad:t = 'yes';"
          if (("spectator" in table[i]) && table[i].spectator)
            trAdd += "spectator:t = 'yes';"
        }
      }
      else if (hdr[j] == "unitIcon") {
        //creating empty unit class/dead icon and weapons icons, and expSkillBonusIcon, to be filled in update func
        let images = params?.canHasBonusIcon ? [createExpSkillBonusIcon("onSkillBonusTooltip")] : []

        foreach (id, _weap in getWeaponTypeIcoByWeapon("", ""))
          images.append(format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-svg-size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0' }", id))

        images.append("div{ size:t='@tableIcoSize,@tableIcoSize' img { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-image:t=''; background-repeat:t='aspect-ratio'; shopItemType:t=''; }}")

        if (isRowInvert)
          images.reverse()
        let cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        let divPos = isRowInvert ? "0" : "pw-w"
        tdData += format("width:t='%s'; tdiv { pos:t='%s, ph/2-h/2'; position:t='absolute'; %s } ", cellWidth, divPos, "".join(images, true))
      }
      else if (hdr[j] == "rank") {
        local prestigeImg = "";
        local rankTxt = ""
        if (!isEmpty && ("exp" in table[i]) && ("prestige" in table[i])) {
          rankTxt = ::get_rank_by_exp(table[i].exp).tostring()
          prestigeImg = $"#ui/gameuiskin#prestige{table[i].prestige}"
        }
        let rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        let prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        let cell = isRowInvert ? prestigeItem + rankItem : rankItem + prestigeItem
        tdData += format("width:t='2.2@rows16height%s'; tdiv { pos:t='%s, 0.5(ph-h)'; position:t='absolute'; " + cell + " } ",
                    widthAdd, isRowInvert ? "0" : "pw-w-1", "0", "0.003sh")
      }
      else if (hdr[j] == "rowNo") {
        local tdProp = ""
        if (hdr[j] in markup)
          tdProp += format("width:t='%s'", getTblValue("width", markup[hdr[j]], ""))

        trAdd += "winnerPlace:t='none';"
        tdData += format("%s activeText { text:t = '%i'; halign:t='center'} ", tdProp, i + 1)
      }
      else if (hdr[j] == "place") {
        let width = "width:t='" + getTblValue("width", markup[hdr[j]], "1") + "'; "
        tdData += format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (isInArray(hdr[j], [ "aiTotalKills", "assists", "score", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ])) {
        let txt = isEmpty ? "" : ::g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData += format("activeText { text:t='%s' halign:t='center' } ", txt)
        let width = getTblValue("width", getTblValue(hdr[j], markup, {}), "")
        if (width != "")
          tdData += format("width:t='%s'; ", width)
      }
      else if (hdr[j] == "numPlayers") {
        let curWidth = ((hdr[j] in markup) && ("width" in markup[hdr[j]])) ? markup[hdr[j]].width : "0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isEmpty && "numPlayersTotal" in table[i]) {
          let maxVal = table[i].numPlayersTotal
          txt += "/" + maxVal
          if (item >= maxVal)
            txtParams += "overlayTextColor:t='warning';"
        }
        tdData += "width:t='" + curWidth + "'; activeText { text:t = '" + txt + "'; " + txtParams + " } "
      }
      else {
        local tdProp = textPadding
        local textType = "activeText"
        let text = ::locOrStrip(item.tostring())
        local halign = "center"
        local pareText = true
        local imageBg = ""

        if (hdr[j] in markup) {
          if ("width" in markup[hdr[j]])
            tdProp += "width:t='" + markup[hdr[j]].width + "'; "
          if ("textDiv" in markup[hdr[j]])
            textType = markup[hdr[j]].textDiv
          if ("halign" in markup[hdr[j]])
            halign =  markup[hdr[j]].halign
          if ("pareText" in markup[hdr[j]])
            pareText =  markup[hdr[j]].pareText
          if ("image" in markup[hdr[j]])
            imageBg = format(" team:t='%s'; " +
              "teamImg {" +
              "css-hier-invalidate:t='yes'; " +
              "id:t='%s';" +
              "background-image:t='%s';" +
              "display:t='%s'; ",
              colorTeam, "icon_" + hdr[j], markup[hdr[j]].image, isEmpty ? "hide" : "show"
            )
        }
        let textParams = format("halign:t='%s'; ", halign)

        tdData += format("%s {" +
          "id:t='%s';" +
          "text:t = '%s';" +
          "max-width:t='pw';" +
          "pare-text:t='%s'; " +
          "%s}",
          tdProp + imageBg + textType, "txt_" + hdr[j], text, (pareText ? "yes" : "no"), textParams + ((imageBg == "") ? "" : "}")
        )
      }

      trData += "td { id:t='td_" + hdr[j] + "'; "
        if (j == 0)
          trData += "padding-left:t='@tablePad'; "
        if (j > 0)
          trData += "cellType:t = 'border'; "
        if (j == (hdr.len() - 1))
          trData += "padding-right:t='@tablePad'; "
      trData += tdData + " }"
    }

    if (trData.len() > 0)
      data += "tr {size:t = '" + trSize + "'; " + trAdd + trData + " text-valign:t='center'; css-hier-invalidate:t='all'; }\n"
  }

  return data
}

::update_team_css_label <- function update_team_css_label(nestObj, customPlayerTeam = null) {
  if (!checkObj(nestObj))
    return
  let teamCode = (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) ? ::SessionLobby.team
    : (customPlayerTeam ?? ::get_local_team_for_mpstats())
  nestObj.playerTeam = ::g_team.getTeamByCode(teamCode).cssLabel
}


let function getExpBonusIndexForPlayer(player, expSkillBonuses, skillBonusType) {
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


::set_mp_table <- function set_mp_table(obj_tbl, table, params = {}) {
  let numTblRows = table.len()
  let realTblRows = obj_tbl.childrenCount()
  let numRows = max(numTblRows, realTblRows)
  if (numRows <= 0)
    return

  let showAirIcons = getTblValue("showAirIcons", params, true)
  let continueRowNum = getTblValue("continueRowNum", params, 0)
  let numberOfWinningPlaces = getTblValue("numberOfWinningPlaces", params, -1)
  let playersInfo = params?.playersInfo ?? ::SessionLobby.getPlayersInfo()
  let needColorizeNotInGame = isInFlight()
  let isReplay = is_replay_playing()

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
        table[i].isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId,
          table[i]?.squadId)
      }

      if (hdr == "team") {
        local teamText = ""
        local teamStyle = ""
        switch (item) {
          case 1:
            teamText = "A"
            teamStyle = "a"
            break
          case 2:
            teamText = "B"
            teamStyle = "b"
            break
          default:
            teamText = "?"
            teamStyle = ""
            break
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
        if (checkObj(objReady)) {
          let playerState = ::g_player_state.getStateByPlayerInfo(table[i])
          objReady["background-image"] = playerState.getIcon(table[i])
          objReady["background-color"] = playerState.getIconColor()
          let desc = playerState.getText(table[i])
          objReady.tooltip = (desc != "") ? (loc("multiplayer/state") + loc("ui/colon") + desc) : ""
        }
      }
      else if (hdr == "name") {
        local nameText = item
        if (!player.isBot)
          nameText = ::g_contacts.getPlayerFullName(getPlayerName(nameText), table[i].clanTag)

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
        local tooltip = nameText
        let isLocal = table[i].isLocal
        //isInMySquad check fixes lag of first 4 seconds, when code don't know about player in my squad.
        let isInHeroSquad = table[i]?.isInHeroSquad || ::SessionLobby.isMemberInMySquadById(table[i]?.userId.tointeger())
        objTr.mainPlayer = isLocal ? "yes" : "no"
        objTr.inMySquad  = isInHeroSquad ? "yes" : "no"
        objTr.spectator = table[i]?.spectator ? "yes" : "no"

        let playerInfo = playersInfo?[(table[i].userId).tointeger()]
        if (!isLocal && isInHeroSquad && playerInfo?.auto_squad)
          tooltip = $"{tooltip}\n\n{loc("squad/auto")}\n"

        if (!table[i].isBot
          && get_mission_difficulty() == ::g_difficulty.ARCADE.gameTypeName
          && !getCurMissionRules().isWorldWar) {
          let data = ::SessionLobby.getBattleRatingParamByPlayerInfo(playerInfo)
          if (data) {
            let squadInfo = getSquadInfo(data.squad)
            let isInSquad = squadInfo ? !squadInfo.autoSquad : false
            let ratingTotal = calcBattleRatingFromRank(data.rank)
            tooltip += "\n" + loc("debriefing/battleRating/units") + loc("ui/colon")
            local showLowBRPrompt = false

            let unitsForTooltip = []
            for (local j = 0; j < min(data.units.len(), 3); ++j)
              unitsForTooltip.append(data.units[j])
            unitsForTooltip.sort(sort_units_for_br_tooltip)
            for (local j = 0; j < unitsForTooltip.len(); ++j) {
              let rankUnused = unitsForTooltip[j].rankUnused
              let formatString = rankUnused
                ? "\n<color=@disabledTextColor>(%.1f) %s</color>"
                : "\n<color=@disabledTextColor>(<color=@userlogColoredText>%.1f</color>) %s</color>"
              if (rankUnused)
                showLowBRPrompt = true
              tooltip += format(formatString, unitsForTooltip[j].rating, unitsForTooltip[j].name)
            }
            tooltip += "\n" + loc(isInSquad ? "debriefing/battleRating/squad" : "debriefing/battleRating/total") +
                              loc("ui/colon") + format("%.1f", ratingTotal)
            if (showLowBRPrompt) {
              let maxBRDifference = 2.0 // Hardcoded till switch to new matching.
              let rankCalcMode = ::SessionLobby.getRankCalcMode()
              if (rankCalcMode)
                tooltip += "\n" + loc("multiplayer/lowBattleRatingPrompt/" + rankCalcMode, { maxBRDifference = format("%.1f", maxBRDifference) })
            }
          }
        }
        objTr.tooltip = tooltip
      }
      else if (hdr == "unitIcon") {
        local unitIco = ""
        local unitIcoColorType = ""
        local unitId = ""
        local weapon = ""

        if (isInFlight() && !isInGame)
          unitIco = ::g_player_state.HAS_LEAVED_GAME.getIcon(player)
        else if (player?.isDead)
          unitIco = (player?.spectator) ? "#ui/gameuiskin#player_spectator.svg" : "#ui/gameuiskin#dead.svg"
        else if (showAirIcons && ("aircraftName" in player)) {
          unitId = player.aircraftName
          unitIco = ::getUnitClassIco(unitId)
          unitIcoColorType = getUnitRole(unitId)
          weapon = player?.weapon ?? ""
        }

        local obj = objTd.findObject("unit-ico")
        if (checkObj(obj)) {
          obj["background-image"] = unitIco
          obj["shopItemType"] = unitIcoColorType
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
          objText.tooltip = tooltip
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
      else if (isInArray(hdr, [ "aiTotalKills", "assists", "score", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ])) {
        let paramType = ::g_mplayer_param_type.getTypeById(hdr)
        let txt = paramType ? paramType.printFunc(item, table[i]) : ""
        let objText = objTd.getChild(0)
        objText.setValue(txt)
        objText.tooltip = paramType ? paramType.getTooltip(item, table[i], txt) : ""
      }
      else if (hdr == "numPlayers") {
        local txt = item.tostring()
        if ("numPlayersTotal" in table[i])
          txt += "/" + table[i].numPlayersTotal
        objTd.getChild(0).setValue(txt)
      }
      else if (hdr == "squad") {
        let squadInfo = isShowSquad() ? getSquadInfoByMemberId(table[i]?.userId.tointeger()) : null
        let squadId = getTblValue("squadId", squadInfo, INVALID_SQUAD_ID)
        let labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        let needSquadIcon = labelSquad != ""
        let squadScore = needSquadIcon ? getTblValue("squadScore", table[i], 0) : 0
        let isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == getTopSquadId(squadInfo.teamId)

        let cellText = objTd.findObject("txt_" + hdr)
        if (checkObj(cellText))
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")

        let cellIcon = objTd.findObject("icon_" + hdr)
        if (checkObj(cellIcon)) {
          cellIcon.show(needSquadIcon)
          if (needSquadIcon) {
            cellIcon["iconSquad"] = squadInfo.autoSquad ? "autosquad" : "squad"
            cellIcon["topSquad"] = isTopSquad ? "yes" : "no"
            cellIcon["tooltip"] = format("%s %s%s", loc("options/chat_messages_squad"), loc("ui/number_sign", "#"), labelSquad)
              + "\n" + loc("profile/awards") + loc("ui/colon") + squadScore
              + (isTopSquad ? ("\n" + loc("streaks/squad_best")) : "")

            if (isReplay)
              objTd.team = squadInfo.teamId == ::get_player_army_for_hud() ? "blue" : "red"
          }
        }
      }
      else {
        local txt = item.tostring()
        if (txt.len() > 0 && txt[0] == '#')
          txt = loc(txt.slice(1))
        let objText = objTd.findObject("txt_" + hdr)
        if (objText) {
          objText.setValue(txt)
          objText.tooltip = txt
        }
      }
    }
  }
}

::getCurMpTitle <- function getCurMpTitle() {
  local text = ""

  if (getCurMissionRules().isWorldWar && ::is_worldwar_enabled()) {
    text = ::g_world_war.getCurMissionWWBattleName()
    text = (text.len() > 0 ? loc("ui/comma") : "").concat(text, locCurrentMissionName())
  }
  else {
    let gm = get_game_mode()
    if (gm == GM_DOMINATION) {
      let diffCode = get_mission_difficulty_int()
      text = ::g_difficulty.getDifficultyByDiffCode(diffCode).getLocName()
    }
    else if (gm == GM_SKIRMISH)
      text = loc("multiplayer/skirmishMode")
    else if (gm == GM_CAMPAIGN)
      text = loc("mainmenu/btnCampaign")
    else if (gm == GM_SINGLE_MISSION)
      text = loc("mainmenu/btnCoop")
    else if (gm == GM_DYNAMIC)
      text = loc("mainmenu/btnDynamic")
    else if (gm == GM_BUILDER)
      text = loc("mainmenu/btnBuilder")
    //else if (gm==GM_TOURNAMENT)       text = loc("multiplayer/tournamentMode")

    text += ((text.len()) ? loc("ui/comma") : "") + locCurrentMissionName()
  }

  return text
}

::getUnitClassIco <- function getUnitClassIco(unit) {
  local unitName = unit?.name ?? ""
  if (type(unit) == "string") {
    unitName = unit
    unit = getAircraftByName(unit)
  }
  return unitName == "" ? ""
    : unit?.customClassIco ?? $"#ui/gameuiskin#{unitName}_ico.svg"
}

::getUnitClassColor <- function getUnitClassColor(unit) {
  let role = getUnitRole(unit) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  if (role == null || role == "" || role == "none")
    return "white";
  return role + "Color"
}

::get_weapon_icons_text <- function get_weapon_icons_text(unitName, weaponName) {
  if (!weaponName || u.isEmpty(weaponName))
    return ""

  let unit = getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponIconsText = ""
  foreach (weapon in unit.getWeapons())
    if (weapon.name == weaponName) {
      foreach (paramName in [WEAPON_TAG.BOMB, WEAPON_TAG.ROCKET,
        WEAPON_TAG.TORPEDO, WEAPON_TAG.ADD_GUN])
          if (weapon[paramName])
            weaponIconsText += loc("weapon/" + paramName + "Icon")
      break
    }

  return colorize("weaponPresetColor", weaponIconsText)
}

::count_width_for_mptable <- function count_width_for_mptable(objTbl, markup) {
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
}