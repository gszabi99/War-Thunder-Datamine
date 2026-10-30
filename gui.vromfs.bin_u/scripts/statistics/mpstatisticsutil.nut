import "%scripts/replays/spectatorWatchedHero.nut" as spectatorWatchedHero
import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "console" import register_command
from "dagor.random" import rnd
from "eventbus" import eventbus_subscribe
from "matching.errors" import INVALID_SQUAD_ID
from "string" import format
from "%scripts/sqDagui/daguiUtil.nut" import show_obj
from "replays" import is_replay_playing
from "mission" import get_game_mode, get_mp_local_team, get_game_type
from "guiMission" import get_mission_difficulty_int, get_mp_session_info, get_player_army_for_hud
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "blkGetters" import get_game_settings_blk, get_ranks_blk
from "gameplayBinding" import isInFlight
from "%scripts/dagui_natives.nut" import get_mp_kick_countdown
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/playerStateConsts.nut" import *
from "%scripts/utils_sa.nut" import locOrStrip
from "%scripts/mplayerParamType.nut" import g_mplayer_param_type
from "%scripts/teams.nut" import g_team
from "%scripts/difficulty.nut" import g_difficulty
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/unit/unitInfoRoles.nut" import getUnitRole
from "%scripts/statistics/squadIcon.nut" import updateTopSquadScore, isShowSquad, getSquadInfoByMemberId, getTopSquadId
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/missions/missionsText.nut" import locCurrentMissionName
from "%scripts/matchingRooms/sessionLobbyState.nut" import sessionLobbyStatus, getSessionLobbyTeam
from "%scripts/misCustomRules/missionCustomState.nut" import getCurMissionRules
from "%scripts/ranks.nut" import getRankByExp
from "%scripts/globalWorldWarScripts.nut" import isWorldWarEnabled
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/contacts/contactsInfo.nut" import getPlayerFullName, colorizeWhitePsnIcon
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import isMemberInMySquadById
from "%scripts/squads/squadState.nut" import isEqualSquadId
from "%scripts/statistics/mpStatisticsInfo.nut" import getWeaponTypeIcoByWeapon
from "%scripts/worldWar/worldWarState.nut" import getCurMissionWWBattleName
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%sqStdLibs/helpers/u.nut" import isEmpty

let { g_player_state } = require("%scripts/contacts/playerStateTypes.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
require("%scripts/statistics/mpStatisticsPlayerTooltip.nut")
let { g_mission_type } = require("%scripts/missions/missionType.nut")

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

let colsWithParamType = { aiTotalKills = true, assists = true, score = true, damageZone = true,
  raceFinishTime = true, raceLastCheckpoint = true, raceLastCheckpointTime = true, damageZoneNuke = true,
  raceBestLapTime = true, missionAliveTime = true, kills = true, deaths = true, navalKills = true
}

let colsWithCustomTooltip = { name = true, aircraft = true, unitIcon = true, score = true }
let colsWithWishlistContextMenu = hasFeature("Wishlist")
  ? { aircraft = true, unitIcon = true }
  : { }

function gui_start_mpstatscreen_(params = {}) {
  let isFromGame = params?.isFromGame ?? false
  handlersManager.loadHandler(get_gui_handler("MPStatisticsModal"),
    {
      backSceneParams = isFromGame ? null : handlersManager.getLastBaseHandlerStartParams(),
    }.__update(params))
}

eventbus_subscribe("gui_start_mpstatscreen_", gui_start_mpstatscreen_)

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

local getMpKickCountdownDebug = null
let getMpKickCountdown = @() (getMpKickCountdownDebug ?? get_mp_kick_countdown)()

function hud_show_in_battle_time_to_kick_timer() {
  let time = get_mp_kick_countdown() + 5000
  getMpKickCountdownDebug = @() time
  set_in_battle_time_to_kick_show_timer(time)
}

function hud_show_in_battle_time_to_kick_alert() {
  let getrndtime = @() rnd() % 5000
  getMpKickCountdownDebug = getrndtime
  set_in_battle_time_to_kick_show_alert(getrndtime())
}

function hud_reset_in_battle_time_to_kick() {
  getMpKickCountdownDebug = null
  let gmSettingsBlk = get_game_settings_blk()
  set_in_battle_time_to_kick_show_timer(gmSettingsBlk?.time_to_kick.in_battle_show_timer_threshold ?? 150)
  set_in_battle_time_to_kick_show_alert(gmSettingsBlk?.time_to_kick.in_battle_show_alert_threshold ?? 50)
}

function getLocalTeamForMpStats(team = null) {
  return (team ?? get_mp_local_team()) != g_team.B.code ? g_team.A.code : g_team.B.code
}

function createExpSkillBonusIcon(tooltipFunction) {
  return "".concat("statsImg{ id:t='exp_skill_bonus_icon'; not-input-transparent:t='yes'; tooltip:t='$tooltipObj'; size:t='@tableIcoSize, @tableIcoSize';",
    "top:t='0.5ph-0.5h'; position:t='relative';background-image:t='';",
    "background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-color:t='@white'; left:t='0'; margin:t='2@dp, 0'; tooltipObj{", $"on_tooltip_open:t='{tooltipFunction}';",
    " display:t='hide'}}"
  )
}

let createBaseTooltip = @(tooltipId) format(
  @"tooltip:t='$tooltipObj';
  tooltipObj {
    id:t='%s';
    on_tooltip_open:t='onGenericTooltipOpen';
    on_tooltip_close:t='onTooltipObjClose';
    display:t='hide'
  }",
  tooltipId
)

const DELAYED_TOOLTIP_MARKUP =
  @"behavior:t='button'
  on_pushed:t='gcb.delayedTooltipPush'
  on_hold_start:t='gcb.delayedTooltipHoldStart'
  on_hold_stop:t='gcb.delayedTooltipHoldStop'
  on_hover:t='gcb.delayedTooltipHover'
  on_unhover:t='gcb.delayedTooltipHover'
  on_r_click:t='onUserRClick'
  tooltipId:t=''
  focusBtnName:t='A'"

let createCellCustomTooltip = @(tooltipId) showConsoleButtons.get() ? DELAYED_TOOLTIP_MARKUP : createBaseTooltip(tooltipId)

local cachedColorsTable = null

function getColorsTable() {
  let isEmptyTable = cachedColorsTable == null
  if (isEmptyTable)
    cachedColorsTable = {}

  local mainGuiScene = get_main_gui_scene()
  cachedColorsTable.teamBlue <- mainGuiScene.getConstantValue("teamBlueColor")
  cachedColorsTable.teamRed <- mainGuiScene.getConstantValue("teamRedColor")
  cachedColorsTable.teamBlueInactive <- mainGuiScene.getConstantValue("teamBlueInactiveColor")
  cachedColorsTable.teamRedInactive <- mainGuiScene.getConstantValue("teamRedInactiveColor")
  cachedColorsTable.mainPlayer <- mainGuiScene.getConstantValue("mainPlayerColor")
  cachedColorsTable.squad <- mainGuiScene.getConstantValue("mySquadColor")

  if (isEmptyTable) {
    cachedColorsTable.spectator <- mainGuiScene.getConstantValue("spectatorColor")
    cachedColorsTable.even <- mainGuiScene.getConstantValue("evenTrColor")
    cachedColorsTable.transparent <- mainGuiScene.getConstantValue("transparent")
    cachedColorsTable.commonText <- mainGuiScene.getConstantValue("commonTextColor")
  }
  return cachedColorsTable
}

function getPlayerTeamCode(customPlayerTeamCode = null) {
  if (isInFlight() || is_replay_playing())
    return customPlayerTeamCode ?? get_player_army_for_hud()

  return (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) ? getSessionLobbyTeam()
    : (customPlayerTeamCode ?? getLocalTeamForMpStats())
}

function getTextColor(data, playerTeamCode, colorsTable, isTeamplay) {
  let needColorizeNotInGame = isInFlight()

  local isInGame = true
  if (needColorizeNotInGame)
    isInGame = data.state == PLAYER_IN_FLIGHT || data.state == PLAYER_IN_RESPAWN

  
  let isInHeroSquad = data?.isInHeroSquad || isMemberInMySquadById(data?.userId.tointeger())
  local color = ""
  if (("spectator" in data) && data.spectator)
    color = colorsTable.spectator
  else if (data?.isLocal)
    color = colorsTable.mainPlayer
  else if (isInHeroSquad)
    color = colorsTable.squad
  else if (playerTeamCode > 0 && (data?.team == g_team.A.code || data?.team == g_team.B.code)) {
    if (data?.team == playerTeamCode && isTeamplay)
      color = isInGame ? colorsTable.teamBlue : colorsTable.teamBlueInactive
    else
      color = isInGame ? colorsTable.teamRed : colorsTable.teamRedInactive
  } else
    color = colorsTable.commonText
  return color
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
  let smallFont   = markupData?.smallFont ?? false

  let markup = markupData.columns

  if (isRowInvert) {
    hdr = clone hdr
    hdr.reverse()
  }

  let { hasCustomTooltip = false, isTeamplay = true } = params
  let colorsTable = getColorsTable()
  let fontSize = smallFont ? "@fontSmall" : "@fontNormal"
  let defaultTextParams = $"font:t='{fontSize}'; word-wrap:t='no';"

  let data = []
  let playerTeamCode = getPlayerTeamCode()

  for (local i = 0; i < numRows; i++) {
    let isRowEmpty = i >= numTblRows
    let trData = []
    let trAdd = [isRowEmpty ? "inactive:t='yes'; " : ""]
    if (!isEmpty(trOnHover))
      trAdd.append($"rowIdx='{i}'; on_hover:t='{trOnHover}'; on_unhover:t='{trOnHover}';")

    let tableData = isRowEmpty ? null : table[i]
    local colorProp = ""
    if (!isRowEmpty) {
      let color = getTextColor(tableData, playerTeamCode, colorsTable, isTeamplay)
      if (color != "")
        colorProp = $"color:t='{color}';"
    }

    for (local j = 0; j < hdr.len(); ++j) {
      local item = ""
      local tdData = ""
      let widthAdd = ((j == 0) || (j == (hdr.len() - 1))) ? "+@tablePad" : ""
      const textPadding = "padding:t='@tablePad, 0'; "
      let customTooltipId = hasCustomTooltip && hdr[j] in colsWithCustomTooltip
        ? $"{hdr[j]}_tooltip"
        : null

      if (!isRowEmpty && (hdr[j] in tableData))
        item = tableData[hdr[j]]

      let customTooltip = customTooltipId
        ? createCellCustomTooltip(customTooltipId)
        : ""
      let idText = $"id:t='td_{hdr[j]}'; "
      if (hdr[j] == "hasPassword") {
        let icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData = "".concat("statCell { position:t='relative'; valign:t='center'; size:t='ph", widthAdd, " ,ph';", idText,
          "statsImg{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize, @tableIcoSize'; ",
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='", isRowEmpty ? "" : icon, "'; }}")
      }
      else if (hdr[j] == "team") {
        let teamText = "teamImg{ position:t='relative'; height:t='@tableIcoSize'; width:t='h'; pos:t='50%pw-50%w, 50%ph-50%h'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; } "
        tdData = "".concat("statCell { ", idText, "position:t='relative'; css-hier-invalidate:t='yes'; valign:t='center'; size:t='ph", widthAdd, ",ph'; team:t=''; ", teamText, "}")
      }
      else if (hdr[j] == "country" || hdr[j] == "teamCountry") {
        local country = ""
        if (hdr[j] == "country")
          country = item
        else if (!isRowEmpty && ("team" in tableData))
            country = get_mp_country_by_team(tableData.team)

        local icon = ""
        if (!isRowEmpty && country != "")
          icon = getCountryIcon(country)
        tdData = format("".concat("statCell { position:t='relative'; valign:t='center'; size:t='ph%s,ph'; ", idText,
          "statsImg{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize, 0.66@tableIcoSize'; background-color:t='@white'; ",
          "background-image:t='%s'; background-svg-size:t='@tableIcoSize, 0.66@tableIcoSize'; background-repeat:t='aspect-ratio'; %s",
          "}}"), widthAdd, icon, customTooltip)
      }
      else if (hdr[j] == "status") {
        tdData = format("statCell {position:t='relative'; valign:t='center'; %s size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico'; valign:t='center'} %s}", idText, widthAdd, customTooltip)
      }
      else if (hdr[j] == "name") {
        local nameText = item
        if (!isRowEmpty && !isHeader && !tableData?.isBot)
          nameText = getPlayerFullName(getPlayerName(nameText), tableData?.clanTag)

        nameText = stripTags(colorizeWhitePsnIcon(nameText))
        let nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        let nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData = "".concat("statText { position:t='relative'; valign:t='center';",
          $"{idText} {nameAlign} {defaultTextParams} text:t = '{nameText}'; {colorProp} ",
          $"pare-text:t='yes'; valign:t='center'; width:t='{nameWidth}'; {textPadding} {customTooltip}",
          "}"
        )
      }
      else if (hdr[j] == "unitIcon") {
        
        let images = params?.canHasBonusIcon ? [createExpSkillBonusIcon("onSkillBonusTooltip")] : []

        foreach (id, _weap in getWeaponTypeIcoByWeapon("", ""))
          images.append(format("statsImg { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-svg-size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0'; bgColor:t='@white'; display:t='hide' }", id))

        images.append("statsImg { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-image:t=''; background-repeat:t='aspect-ratio'; bgColor:t='@white'; display:t='hide'}")

        if (isRowInvert)
          images.reverse()
        let cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        let divPos = isRowInvert ? "0" : "pw-w"
        tdData = format("statCell {position:t='relative'; contextMenu:t='no'; cursor:t='normal'; valign:t='center'; %s width:t='%s'; height:t='@tableIcoSize'; statCell { left:t='%s'; position:t='absolute'; %s  } %s }", idText, cellWidth, divPos, "".join(images, true), customTooltip)
      }
      else if (hdr[j] == "rank") {
        local prestigeImg = ""
        local rankTxt = ""
        if (!isRowEmpty && ("exp" in tableData) && ("prestige" in tableData)) {
          rankTxt = getRankByExp(tableData.exp).tostring()
          prestigeImg = $"#ui/gameuiskin#prestige{tableData.prestige}"
        }
        let rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        let prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        let cell = isRowInvert ? $"{prestigeItem}{rankItem}" : $"{rankItem}{prestigeItem}"
        tdData = format("".concat("statCell { position:t='relative'; valign:t='center';", $"{idText} width:t='2.2@rows16height%s';",
          "statCell { pos:t='%s, 0.5(ph-h)'; position:t='absolute';", cell, " }} "),
          widthAdd, isRowInvert ? "0" : "pw-w-1", "0", "0.003sh")
      }
      else if (hdr[j] == "rowNo") {
        let tdProp = []
        if (hdr[j] in markup)
          tdProp.append(format("width:t='%s'", (markup[hdr[j]]?.width ?? "")))

        tdData = format("statText { position:t='relative'; %s %s %s; text:t = '%i'; valign:t='center'; text-align:t='center'; %s} ",
          idText, defaultTextParams, "".join(tdProp), i + 1, colorProp)
      }
      else if (hdr[j] == "place") {
        let width = $"width:t='{markup[hdr[j]]?.width ?? 1}'; "
        tdData = format("statText {position:t='relative'; %s valign:t='center'; %s text:t='%s'; text-align:t='center'} ", width, defaultTextParams, item)
      }
      else if (hdr[j] in colsWithParamType) {
        let txt = isRowEmpty ? "" : g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, tableData)
        let width = ((markup?[hdr[j]] ?? {})?.width ?? "")
        tdData = format("statText { position:t='relative'; %s valign:t='center'; %s text:t='%s'; text-align:t='center'; %s %s %s} ",
          idText, defaultTextParams, txt, width != "" ? $"width:t='{width}';" : "", colorProp, customTooltip
        )
      }
      else if (hdr[j] == "numPlayers") {
        let curWidth = ((hdr[j] in markup) && ("width" in markup[hdr[j]])) ? markup[hdr[j]].width : "0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw';"
        local textColor = colorProp
        if (!isRowEmpty && "numPlayersTotal" in tableData) {
          let maxVal = tableData.numPlayersTotal
          txt = $"{txt}/{maxVal}"
          if (item >= maxVal)
            textColor = $"color:t='@warningTextColor';"
        }
        tdData = format("statText { position:t='relative'; %s %s width:t='%s'; valign:t='center'; text:t='%s'; %s %s text-align:t='center';}",
          idText, defaultTextParams, curWidth, txt, txtParams, textColor)
      }
      else {
        local tdProp = textPadding
        local textType = "statText"
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
          if ("image" in markup[hdr[j]]) {
            textType = markup[hdr[j]]?.textDiv ?? "activeText"
            imageBg = format("".concat("team:t='%s'; css-hier-invalidate:t='yes';",
              "teamImg {id:t='%s'; background-image:t='%s';", "display:t='%s';"),
              colorTeam, $"icon_{hdr[j]}", markup[hdr[j]].image, isRowEmpty ? "hide" : "show"
            )
          }
        }

        if (hdr[j] in colsWithWishlistContextMenu)
          tdProp = "".concat(tdProp, "cursor:t='normal'; contextMenu:t='no'; ")

        let overridedTextParams = textType == "statText"
          ? defaultTextParams
          : $"word-wrap:t='no'; {smallFont ? "smallFont:t='yes';" : ""}"
        if (imageBg != "") {
          tdData = format("".concat("statCell { %s position:t='relative'; valign:t='center'; max-width:t='pw'; ",
          "%s %s {id:t='%s'; position:t='absolute'; %s text:t = '%s'; pare-text:t='%s'; text-align:t='%s'; pos:t='(pw-w)/2, (ph-h)/2'; %s}} %s %s}"),
            idText, imageBg, textType, $"txt_{hdr[j]}" , overridedTextParams, text, pareText ? "yes" : "no", halign, colorProp,
            tdProp, customTooltip
          )
        } else {
          tdData = format("".concat("%s { position:t='relative'; %s %s text:t = '%s'; max-width:t='pw';",
            "pare-text:t='%s'; valign:t='center'; %s text-align:t='%s'; %s %s}"),
            textType, idText, $"{tdProp}", text, pareText ? "yes" : "no", overridedTextParams, halign, colorProp, customTooltip
          )
        }
      }
      trData.append(tdData)
    }

    data.append("".concat("statLine {input-transparent:t='yes'; css-hier-invalidate:t='yes'; mouse-pointer-centering:t='",
      isRowInvert ? "55, 50" : "50, 55", "'; isContainer:t='yes'; total-input-transparent:t='yes'; flow:t='horizontal'; selected:t='no';  size:t = '", trSize, "'; ", "".join(trAdd), "".join(trData),
      "}")
    )
  }

  return "\n".join(data)
}

function updateTeamCssLabel(nestObj, customPlayerTeamCode = null) {
  if (!checkObj(nestObj))
    return
  let teamCode = getPlayerTeamCode(customPlayerTeamCode)
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
  local numRows = max(numTblRows, realTblRows)
  if (numRows <= 0)
    return

  let { showUnitsInfo = true, continueRowNum = 0, numberOfWinningPlaces = -1,
    isDebriefing = false, hasCustomTooltip = false, friendlyTeamCode = -1, isTeamplay = true,
    playerTooltipType = "MP_STAT_PLAYER" } = params
  let needColorizeNotInGame = isInFlight()
  let isReplay = is_replay_playing()
  let playerTeamCode = friendlyTeamCode >= 0 ? friendlyTeamCode : getPlayerTeamCode()

  let colorsTable = getColorsTable()
  let mainGuiScene = get_main_gui_scene()
  updateTopSquadScore(table)

  let createCount = numRows - realTblRows
  obj_tbl.getChild(0).getClone(obj_tbl, params?.handler, createCount)

  for (local i = 0; i < numRows; i++) {
    let objTr = obj_tbl.getChild(i)
    if (objTr?.rowIdx != null)
      objTr.rowIdx = i.tostring()
    let isEven = (i % 2 == 0)
    if (realTblRows <= i && objTr?.selected)
      objTr.selected = "no"
    if ((objTr?.selected != "yes") || (realTblRows <= i))
      objTr.bgColor = isEven ? colorsTable.even : colorsTable.transparent

    let isRowEmpty = i >= numTblRows
    objTr.inactive = isRowEmpty ? "yes" : "no"
    show_obj(objTr, !isRowEmpty)
    if (isRowEmpty)
      continue

    let player = table[i]
    if (isReplay) {
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = isEqualSquadId(spectatorWatchedHero.squadId,
        player?.squadId)
    }

    local isInGame = true
    if (needColorizeNotInGame)
      isInGame = player?.state == PLAYER_IN_FLIGHT || player?.state == PLAYER_IN_RESPAWN

    let isAlly = isTeamplay && (player.team == playerTeamCode)
    let textColor = getTextColor(player, playerTeamCode, colorsTable, isTeamplay)
    let unitCardTooltipId = hasCustomTooltip && showUnitsInfo ? getUnitCardTooltipId(player) : null

    let totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++) {
      let objTd = objTr.getChild(idx)
      let id = objTd?.id
      if (!id || id.len() < 4 || id.slice(0, 3) != "td_")
        continue

      let hdr = id.slice(3)
      local item = ""

      if (hdr in player)
        item = player[hdr]

      if (hdr in colsWithWishlistContextMenu) {
        let hasUnitCard = !!unitCardTooltipId
        objTd.cursor = hasUnitCard ? "context-menu" : "normal"
        objTd.contextMenu = hasUnitCard ? "wishlist" : "no"
      }

      if (hdr == "team")
        objTd["team"] = item == 1 ? "a" : item == 2 ? "b" : ""
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

        objTd.setValue(colorizeWhitePsnIcon(nameText))
        objTd.color = textColor;

        let objDlcImg = objTr.findObject("dlc-ico")
        if (checkObj(objDlcImg))
          objDlcImg.show(false)

        let userIdInt = player.userId.tointeger()
        if (hasCustomTooltip && (!player.isBot || (isReplay && userIdInt > 0))) {
          let tooltipId = getTooltipType(playerTooltipType).getTooltipId(player.userId, { isAlly, isDebriefing })
          let baseTooltipObj = objTd.findObject("name_tooltip")
          if (baseTooltipObj?.isValid()) {
            baseTooltipObj.tooltipId = tooltipId
            objTd.tooltip = "$tooltipObj"
          }
          else
            objTd.tooltipId = tooltipId
        } else {
          objTd.tooltip = nameText
        }
      }
      else if (hdr == "unitIcon") {
        local unitIco = ""
        local unitIcoColorType = ""
        local unitId = ""
        local weapon = ""

        if (needColorizeNotInGame && !isInGame)
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
        if (obj.isValid()) {
          if (unitIco == "")
            show_obj(obj, false)
          else {
            obj["background-image"] = unitIco
            let isWhiteIcon = unitIco.endswith(ICON_SKIP_BG_COLORING)
            let color = isWhiteIcon ? "#FFFFFF" : (mainGuiScene.getConstantValue($"{unitIcoColorType}Color") ?? "#FFFFFF")
            obj["bgColor"] = color
            show_obj(obj, true)
          }
        }

        if (params?.canHasBonusIcon) {
          let roomEventName = params?.roomEventName ?? ""
          let expSkillBonuses = get_ranks_blk()?.ExpSkillBonus[roomEventName]
          let skillBonusType = eventNameBonusTypes?[roomEventName]

          let bonusIndex = getExpBonusIndexForPlayer(player, expSkillBonuses, skillBonusType)
          let nameIcon = objTd.findObject("exp_skill_bonus_icon")
          if (checkObj(nameIcon)) {
            nameIcon["background-image"] = bonusIndex > 0 ? $"#ui/gameuiskin#skill_bonus_level_{bonusIndex}.svg" : ""
            show_obj(nameIcon, bonusIndex > 0)
          }
        }

        foreach (iconId, weap in getWeaponTypeIcoByWeapon(unitId, weapon)) {
          obj = objTd.findObject($"{iconId}-ico")
          if (checkObj(obj)) {
            let iconSize = $"{weap.ratio}@tableIcoSize,@tableIcoSize"
            obj.size = iconSize
            obj["background-image"] = weap.icon
            obj["background-svg-size"] = iconSize
            show_obj(obj, (weap.icon && !(weap.icon == "")))
          }
        }
        if (unitCardTooltipId) {
          let baseTooltipObj = objTd.findObject("unitIcon_tooltip")
          if (baseTooltipObj?.isValid()) {
            objTd.tooltip = "$tooltipObj"
            baseTooltipObj.tooltipId = unitCardTooltipId
          }
          else
            objTd.tooltipId = unitCardTooltipId
        }
        else
          objTd.tooltip = ""
      }
      else if (hdr == "aircraft") {
        local text = ""
        local tooltip = ""
        if (table[i]?.spectator ?? false) {
          text = loc("mainmenu/btnReferee")
          tooltip = loc("multiplayer/state/player_referee")
        }
        else {
          let unitId = table[i]?.aircraftName ?? ""
          text = (unitId != "") ? loc(getUnitName(unitId, true)) : "..."
          tooltip = (unitId != "") ? loc(getUnitName(unitId, false)) : ""
        }
        objTd.setValue(text)
        objTd.color = textColor

        if (unitCardTooltipId) {
          let baseTooltipObj = objTd.findObject("aircraft_tooltip")
          if (baseTooltipObj?.isValid()) {
            baseTooltipObj.tooltipId = unitCardTooltipId
            objTd.tooltipId = ""
          }
          else {
            objTd.tooltipId = unitCardTooltipId
          }
          if (!showConsoleButtons.get())
            objTd.tooltip = "$tooltipObj"
        }
        else {
          objTd.tooltip = tooltip
        }
      }
      else if (hdr == "rowNo") {
        let tablePos = i + 1
        let pos = tablePos + continueRowNum
        objTd.setValue(pos.tostring())
        local placeTextColor = textColor
        if (numberOfWinningPlaces > 0 && (table[i]?.raceLastCheckpoint ?? 0) > 0) {
          if (tablePos == 1)
            placeTextColor = mainGuiScene.getConstantValue("raceMode1stPlace")
          else if (tablePos <= numberOfWinningPlaces)
            placeTextColor = mainGuiScene.getConstantValue("raceMode2ndPlace")
        }
        objTd.color = placeTextColor
      }
      else if (hdr == "place") {
        objTd.setValue(item)
        objTd.color = textColor
      }
      else if (hdr in colsWithParamType) {
        let paramType = g_mplayer_param_type.getTypeById(hdr)
        let txt = paramType ? paramType.printFunc(item, table[i]) : ""
        let objText = objTd
        objText.setValue(txt)
        objTd.color = textColor

        let tooltipId = !hasCustomTooltip ? ""
          : paramType?.getTooltipId(player.userId, { isDebriefing, paramId = hdr, val = item }) ?? ""
        let hasGenericTooltip = tooltipId != ""

        if (hasGenericTooltip) {
          let baseTooltipObj = objTd.findObject($"{hdr}_tooltip")
          if (baseTooltipObj?.isValid()) {
            baseTooltipObj.tooltipId = tooltipId
            if (!showConsoleButtons.get())
              objTd.tooltip = "$tooltipObj"
          }
          else
            objTd.tooltipId = tooltipId
        }
        else
          objTd.tooltip = paramType?.getTooltip(item, table[i], txt) ?? ""
      }
      else if (hdr == "numPlayers") {
        local txt = item.tostring()
        if ("numPlayersTotal" in table[i])
          txt = "".concat(txt, "/", table[i].numPlayersTotal)
        objTd.color = textColor
        objTd.setValue(txt)
      }
      else if (hdr == "squad") {
        let squadInfo = isShowSquad() ? getSquadInfoByMemberId(table[i]?.userId.tointeger()) : null
        let squadId = (squadInfo?.squadId ?? INVALID_SQUAD_ID)
        let labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        let needSquadIcon = labelSquad != ""
        let squadScore = needSquadIcon ? (table[i]?.squadScore ?? 0) : 0
        
        let isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == getTopSquadId(squadInfo?.teamId)

        let cellText = objTd.findObject($"txt_{hdr}")
        if (checkObj(cellText)) {
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")
          cellText.color = textColor
        }

        let cellIcon = objTd.findObject($"icon_{hdr}")
        if (checkObj(cellIcon)) {
          cellIcon.show(needSquadIcon)
          if (needSquadIcon) {
            cellIcon["iconSquad"] = squadInfo?.autoSquad ? "autosquad" : "squad"
            cellIcon["topSquad"] = isTopSquad ? "yes" : "no"
            cellIcon["tooltip"] = "".concat(format("%s %s%s", loc("options/chat_messages_squad"), loc("ui/number_sign", "#"), labelSquad),
              "\n", loc("profile/awards"), loc("ui/colon"), squadScore,
              (isTopSquad ? $"\n{loc("streaks/squad_best")}" : ""))

            if (isReplay)
              objTd.team = squadInfo?.teamId == get_player_army_for_hud() ? "blue" : "red"
          }
        }
      }
      else {
        local txt = item.tostring()
        if (txt.len() > 0 && txt[0] == '#')
          txt = loc(txt.slice(1))
        let objText = objTd.findObject($"txt_{hdr}") ?? objTd
        if (objText?.setValue) {
          objText.setValue(txt)
          objText.color = textColor
        }

        objTd.tooltip = g_mplayer_param_type.getTypeById(hdr).getDefTooltip(txt)
      }
    }
  }

}

function getCurMpTitle() {
  let text = []

  if (getCurMissionRules().isWorldWar && isWorldWarEnabled()) {
    text.append(getCurMissionWWBattleName())
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

const TEAMMATE_STATS_FIELDS = ["humanKills", "navalKills", "groundKills", "kills", "deaths"]
const MAX_TEAMMATE_STATS_ROWS = 3

let teammateStatIconMarkup = @(iconLocId, isLeftSide)
@"textareaNoTab {
  size:t='ph, ph'
  text:t='#icon/mpstats/{0}'
  margin:t='{1}'
  tinyFont:t='yes'
  text-align:t='center'
}".subst(iconLocId, isLeftSide ? "0,0,3@sf/@pf,0" : "3@sf/@pf,0,0,0")

let teammateStatValueMarkup = @(iconLocId, isLeftSide)
@"textareaNoTab {
  id:t='{0}'
  text:t='0'
  tinyFont:t='yes'
  text-align:t='{1}'
}".subst(iconLocId, isLeftSide ? "left" : "right")

function getSpectatorTeammateStatsMarkup(isLeftSide) {
  let statsRows = []
  let misObjectives = g_mission_type.getCurrentObjectives()
  let gt = get_game_type()
  let gm = get_game_mode()
  local emptyRowsLeft = MAX_TEAMMATE_STATS_ROWS
  foreach (statId in TEAMMATE_STATS_FIELDS) {
    if (!g_mplayer_param_type.getTypeById(statId).isVisible(misObjectives, gt, gm)
      || (emptyRowsLeft == 1 && statId != "deaths") 
    )
      continue

    let iconMarkup = teammateStatIconMarkup(statId, isLeftSide)
    let valueMarkup = teammateStatValueMarkup(statId, isLeftSide)
    statsRows.append({
      col1 = isLeftSide ? iconMarkup : valueMarkup
      col2 = isLeftSide ? valueMarkup : iconMarkup
    })

    emptyRowsLeft -= 1
    if (emptyRowsLeft == 0)
      break
  }
  return statsRows
}

function getSpectatorTeammateStats(player) {
  let res = {}
  foreach (statId in TEAMMATE_STATS_FIELDS)
    res[statId] <- g_mplayer_param_type.getTypeById(statId).printFunc(player?[statId], player)

  return res
}

register_command(hud_show_in_battle_time_to_kick_timer, "debug.hud.show_in_battle_time_to_kick_timer")
register_command(hud_show_in_battle_time_to_kick_alert, "debug.hud.show_in_battle_time_to_kick_alert")
register_command(hud_reset_in_battle_time_to_kick, "debug.hud.reset_in_battle_time_to_kick")

return freeze({
  guiStartMPStatScreen
  guiStartMPStatScreenFromGame
  set_time_to_kick_show_alert
  get_time_to_kick_show_alert
  get_in_battle_time_to_kick_show_alert
  get_in_battle_time_to_kick_show_timer
  get_time_to_kick_show_timer
  set_time_to_kick_show_timer
  getCurMpTitle
  setMpTable
  getLocalTeamForMpStats
  buildMpTable
  updateTeamCssLabel
  countWidthForMpTable
  getMpKickCountdown
  getSpectatorTeammateStatsMarkup
  getSpectatorTeammateStats
  TEAMMATE_STATS_FIELDS
})