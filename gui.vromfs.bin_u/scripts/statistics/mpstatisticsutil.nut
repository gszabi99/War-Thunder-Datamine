let platformModule = require("%scripts/clientState/platform.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { WEAPON_TAG } = require("%scripts/weaponry/weaponryInfo.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { updateTopSquadScore, getSquadInfo,isShowSquad,
  getSquadInfoByMemberName, getTopSquadId } = require("%scripts/statistics/squadIcon.nut")
let { updateNameMapping } = require("%scripts/user/nameMapping.nut")

::gui_start_mpstatscreen_ <- function gui_start_mpstatscreen_(params = {}) // used from native code
{
  let isFromGame = params?.isFromGame ?? false
  let handler = ::handlersManager.loadHandler(::gui_handlers.MPStatisticsModal,
    {
      backSceneFunc = isFromGame ? null : ::handlersManager.getLastBaseHandlerStartFunc(),
    }.__update(params))

  if (isFromGame)
    ::statscreen_handler = handler
}

let function guiStartMPStatScreen()
{
  gui_start_mpstatscreen_({ isFromGame = false })
  ::handlersManager.setLastBaseHandlerStartFunc(guiStartMPStatScreen)
}

let function guiStartMPStatScreenFromGame()
{
  gui_start_mpstatscreen_({ isFromGame = true })
  ::handlersManager.setLastBaseHandlerStartFunc(guiStartMPStatScreenFromGame)
}

::gui_start_mpstatscreen_from_game <- @() guiStartMPStatScreenFromGame() // used from native code
::gui_start_flight_menu_stat <- @() guiStartMPStatScreenFromGame() // used from native code
//!!!FIX Rebuild global functions below to local
::time_to_kick_show_timer <- null
::time_to_kick_show_alert <- null
::in_battle_time_to_kick_show_timer <- null
::in_battle_time_to_kick_show_alert <- null

::get_time_to_kick_show_timer <- function get_time_to_kick_show_timer()
{
  if (::time_to_kick_show_timer == null)
  {
    ::time_to_kick_show_timer = ::get_game_settings_blk()?.time_to_kick.show_timer_threshold ?? 30
  }
  return ::time_to_kick_show_timer
}

::get_time_to_kick_show_alert <- function get_time_to_kick_show_alert()
{
  if (::time_to_kick_show_alert == null)
  {
    ::time_to_kick_show_alert = ::get_game_settings_blk()?.time_to_kick.show_alert_threshold ?? 15
  }
  return ::time_to_kick_show_alert
}

::get_in_battle_time_to_kick_show_timer <- function get_in_battle_time_to_kick_show_timer()
{
  if (::in_battle_time_to_kick_show_timer == null)
  {
    ::in_battle_time_to_kick_show_timer = ::get_game_settings_blk()?.time_to_kick.in_battle_show_timer_threshold ?? 150
  }
  return ::in_battle_time_to_kick_show_timer
}

::get_in_battle_time_to_kick_show_alert <- function get_in_battle_time_to_kick_show_alert()
{
  if (::in_battle_time_to_kick_show_alert == null)
  {
    ::in_battle_time_to_kick_show_alert = ::get_game_settings_blk()?.time_to_kick.in_battle_show_alert_threshold ?? 50
  }
  return ::in_battle_time_to_kick_show_alert
}

::get_local_team_for_mpstats <- function get_local_team_for_mpstats(team = null)
{
  return (team ?? ::get_mp_local_team()) != ::g_team.B.code ? ::g_team.A.code : ::g_team.B.code
}

::build_mp_table <- function build_mp_table(table, markupData, hdr, max_rows)
{
  let numTblRows = table.len()
  let numRows = ::max(numTblRows, max_rows)
  if (numRows <= 0)
    return ""

  let isHeader    = markupData?.is_header ?? false
  let trSize      = markupData?.tr_size   ?? "pw, @baseTrHeight"
  let isRowInvert = markupData?.invert    ?? false
  let colorTeam   = markupData?.colorTeam ?? "blue"
  let trOnHover   = markupData?.trOnHover

  let markup = markupData.columns

  if (isRowInvert)
  {
    hdr = clone hdr
    hdr.reverse()
  }

  local data = ""
  for (local i = 0; i < numRows; i++)
  {
    let isEmpty = i >= numTblRows
    local trData = format("even:t='%s'; ", (i%2 == 0)? "yes" : "no")
    local trAdd = isEmpty? "inactive:t='yes'; " : ""
    if (!::u.isEmpty(trOnHover))
      trAdd = "".concat(trAdd, $"rowIdx='{i}'; on_hover:t='{trOnHover}'; on_unhover:t='{trOnHover}';")

    for (local j = 0; j < hdr.len(); ++j)
    {
      local item = ""
      local tdData = ""
      let widthAdd = ((j==0)||(j==(hdr.len()-1)))? "+@tablePad":""
      local textPadding = "style:t='padding:0.005sh,0;'; "
      if (j==0)             textPadding = "style:t='padding:@tablePad,0,0.005sh,0;'; "
      if (j==(hdr.len()-1)) textPadding = "style:t='padding:0.005sh,0,@tablePad,0;'; "

      if (!isEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] == "hasPassword")
      {
        let icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData += "size:t='ph"+widthAdd+" ,ph';"  +
          ("img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';" +
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='" + (isEmpty ? "" : icon) + "'; }")
      }
      else if (hdr[j] == "team")
      {
        let teamText = "teamImg{ text { halign:t='center'}} "
        tdData += "size:t='ph"+widthAdd+",ph'; css-hier-invalidate:t='yes'; team:t=''; " + teamText
      }
      else if (hdr[j] == "country" || hdr[j] == "teamCountry")
      {
        local country = ""
        if (hdr[j] == "country")
          country = item
        else
          if (!isEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        local icon = ""
        if (!isEmpty && country!= "")
          icon = ::get_country_icon(country)
        tdData += ::format("size:t='ph%s,ph';"
          + "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';"
          +   "background-image:t='%s'; background-svg-size:t='@cIco, @cIco';"
          + "}",
          widthAdd, icon)
      }
      else if (hdr[j] == "status")
      {
        tdData = ::format("size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico' } ", widthAdd)
      }
      else if (hdr[j] == "name")
      {
        local nameText = item
        if (!isEmpty && !isHeader && !table[i].isBot) {
          if (table[i]?.realName && table[i].realName != "")
            updateNameMapping(table[i].realName, nameText)

          nameText = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(nameText), table[i].clanTag)
        }

        nameText = ::g_string.stripTags(nameText)

        let nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        let nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData += format ("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s';" +
          "pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s",
          nameWidth, "textareaNoTab", nameAlign, nameText, textPadding
        )

        if (!isEmpty)
        {
          //isInMySquad check fixes lag of first 4 seconds, when code don't know about player in my squad.
          if (table[i]?.isLocal)
            trAdd += "mainPlayer:t = 'yes';"
          else if (table[i]?.isInHeroSquad || ::SessionLobby.isMemberInMySquadByName(item))
            trAdd += "inMySquad:t = 'yes';"
          if (("spectator" in table[i]) && table[i].spectator)
            trAdd += "spectator:t = 'yes';"
        }
      }
      else if (hdr[j] == "unitIcon")
      {
        //creating empty unit class/dead icon and weapons icons, to be filled in update func
        let images = [ "img { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-image:t=''; background-repeat:t='aspect-ratio'; shopItemType:t=''; }" ]
        foreach(id, weap in ::getWeaponTypeIcoByWeapon("", ""))
          images.insert(0, ::format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-svg-size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0' }", id))
        if (isRowInvert)
          images.reverse()
        let cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        let divPos = isRowInvert ? "0" : "pw-w"
        tdData += ::format("width:t='%s'; tdiv { pos:t='%s, ph/2-h/2'; position:t='absolute'; %s } ", cellWidth, divPos, ::g_string.implode(images))
      }
      else if (hdr[j] == "rank")
      {
        local prestigeImg = "";
        local rankTxt = ""
        if (!isEmpty && ("exp" in table[i]) && ("prestige" in table[i]))
        {
          rankTxt = get_rank_by_exp(table[i].exp).tostring()
          prestigeImg = "#ui/gameuiskin#prestige" + table[i].prestige
        }
        let rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        let prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        let cell = isRowInvert ? prestigeItem + rankItem : rankItem + prestigeItem
        tdData += format("width:t='2.2@rows16height%s'; tdiv { pos:t='%s, 0.5(ph-h)'; position:t='absolute'; " + cell + " } ",
                    widthAdd, isRowInvert ? "0" : "pw-w-1", "0", "0.003sh")
      }
      else if (hdr[j] == "rowNo")
      {
        local tdProp = ""
        if (hdr[j] in markup)
          tdProp += ::format("width:t='%s'", ::getTblValue("width", markup[hdr[j]], ""))

        trAdd += "winnerPlace:t='none';"
        tdData += ::format("%s activeText { text:t = '%i'; halign:t='center'} ", tdProp, i+1)
      }
      else if (hdr[j] == "place")
      {
        let width = "width:t='" + ::getTblValue("width", markup[hdr[j]], "1") + "'; "
        tdData += ::format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (::isInArray(hdr[j], [ "aiTotalKills", "assists", "score", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        let txt = isEmpty ? "" : ::g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData += ::format("activeText { text:t='%s' halign:t='center' } ", txt)
        let width = ::getTblValue("width", ::getTblValue(hdr[j], markup, {}), "")
        if (width != "")
          tdData += ::format("width:t='%s'; ", width)
      }
      else if (hdr[j] == "numPlayers")
      {
        let curWidth = ((hdr[j] in markup)&&("width" in markup[hdr[j]]))?markup[hdr[j]].width:"0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isEmpty && "numPlayersTotal" in table[i])
        {
          let maxVal = table[i].numPlayersTotal
          txt += "/" + maxVal
          if (item >= maxVal)
            txtParams += "overlayTextColor:t='warning';"
        }
        tdData += "width:t='" + curWidth + "'; activeText { text:t = '" + txt + "'; " + txtParams + " } "
      }
      else
      {
        local tdProp = textPadding
        local textType = "activeText"
        let text = ::locOrStrip(item.tostring())
        local halign = "center"
        local pareText = true
        local imageBg = ""

        if (hdr[j] in markup)
        {
          if ("width" in markup[hdr[j]])
            tdProp += "width:t='" + markup[hdr[j]].width + "'; "
          if ("textDiv" in markup[hdr[j]])
            textType = markup[hdr[j]].textDiv
          if ("halign" in markup[hdr[j]])
            halign =  markup[hdr[j]].halign
          if ("pareText" in markup[hdr[j]])
            pareText =  markup[hdr[j]].pareText
          if ("image" in markup[hdr[j]])
            imageBg = ::format(" team:t='%s'; " +
              "teamImg {" +
              "css-hier-invalidate:t='yes'; " +
              "id:t='%s';" +
              "background-image:t='%s';" +
              "display:t='%s'; ",
              colorTeam, "icon_"+hdr[j], markup[hdr[j]].image, isEmpty ? "hide" : "show"
            )
        }
        let textParams = format("halign:t='%s'; ", halign)

        tdData += ::format("%s {" +
          "id:t='%s';" +
          "text:t = '%s';" +
          "max-width:t='pw';" +
          "pare-text:t='%s'; " +
          "%s}",
          tdProp+imageBg+textType, "txt_"+hdr[j], text, (pareText ? "yes" : "no"), textParams+((imageBg=="")?"":"}")
        )
      }

      trData += "td { id:t='td_" + hdr[j] + "'; "
        if (j==0)              trData += "padding-left:t='@tablePad'; "
        if (j>0)               trData += "cellType:t = 'border'; "
        if (j==(hdr.len()-1))  trData += "padding-right:t='@tablePad'; "
      trData += tdData + " }"
    }

    if (trData.len() > 0)
      data += "tr {size:t = '" + trSize + "'; " + trAdd + trData + " text-valign:t='center'; css-hier-invalidate:t='all'; }\n"
  }

  return data
}

::update_team_css_label <- function update_team_css_label(nestObj, customPlayerTeam = null)
{
  if (!::check_obj(nestObj))
    return
  let teamCode = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team
    : (customPlayerTeam ?? ::get_local_team_for_mpstats())
  nestObj.playerTeam = ::g_team.getTeamByCode(teamCode).cssLabel
}

::set_mp_table <- function set_mp_table(obj_tbl, table, params)
{
  let max_rows = ::getTblValue("max_rows", params, 0)
  let numTblRows = table.len()
  let numRows = numTblRows > max_rows ? numTblRows : max_rows
  let realTblRows = obj_tbl.childrenCount()

  if ((numRows <= 0)||(realTblRows <= 0))
    return

  let showAirIcons = ::getTblValue("showAirIcons", params, true)
  let continueRowNum = ::getTblValue("continueRowNum", params, 0)
  let numberOfWinningPlaces = ::getTblValue("numberOfWinningPlaces", params, -1)
  let playersInfo = params?.playersInfo ?? ::SessionLobby.getPlayersInfo()
  let isInFlight = ::is_in_flight()
  let needColorizeNotInGame = isInFlight
  let isReplay = ::is_replay_playing()

  updateTopSquadScore(table)

  for (local i = 0; i < numRows; i++)
  {
    local objTr = null
    if (realTblRows <= i)
    {
      objTr = obj_tbl.getChild(realTblRows-1).getClone()
      if (objTr?.rowIdx != null)
        objTr.rowIdx = i.tostring()
    }
    else
      objTr = obj_tbl.getChild(i)

    let isEmpty = i >= numTblRows
    objTr.inactive = isEmpty? "yes" : "no"
    objTr.show(!isEmpty || i < max_rows)
    if (i >= numRows)
      continue

    local isInGame = true
    if (!isEmpty && needColorizeNotInGame)
    {
      let state = table[i].state
      isInGame = state == ::PLAYER_IN_FLIGHT || state == ::PLAYER_IN_RESPAWN
      objTr.inGame = isInGame ? "yes" : "no"
    }

    let totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++)
    {
      let objTd = objTr.getChild(idx)
      let id = objTd?.id
      if (!id || id.len()<4 || id.slice(0, 3)!="td_")
        continue

      let hdr = id.slice(3)
      local item = ""

      if (!isEmpty && (hdr in table[i]))
        item = table[i][hdr]

      if (!isEmpty && isReplay)
      {
        table[i].isLocal = spectatorWatchedHero.id == table[i].id
        table[i].isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId,
          table[i]?.squadId)
      }

      if (hdr == "team")
      {
        local teamText = ""
        local teamStyle = ""
        switch (item)
        {
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

        if (isEmpty)
        {
          teamText = ""
          teamStyle = ""
        }

        objTd.getChild(0).setValue(teamText)
        objTd["team"] = teamStyle
      }
      else if (hdr == "country" || hdr == "teamCountry")
      {
        local country = ""
        if (hdr == "country")
          country = item
        else
          if (!isEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        let objImg = objTd.getChild(0)
        local icon = ""
        if (!isEmpty && country != "")
          icon = ::get_country_icon(country)
        objImg["background-image"] = icon
      }
      else if (hdr == "status")
      {
        let objReady = objTd.findObject("ready-ico")
        if (::check_obj(objReady))
        {
          if (isEmpty)
            objReady["background-image"] = ""
          else
          {
            let playerState = ::g_player_state.getStateByPlayerInfo(table[i])
            objReady["background-image"] = playerState.getIcon(table[i])
            objReady["background-color"] = playerState.getIconColor()
            let desc = playerState.getText(table[i])
            objReady.tooltip = (desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : ""
          }
        }
      }
      else if (hdr == "name")
      {
        local nameText = item
        if (!isEmpty)
        {
          if (!table[i].isBot) {
            if (table[i]?.realName && table[i].realName != "")
              updateNameMapping(table[i].realName, nameText)

            nameText = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(nameText), table[i].clanTag)
          }

          if (table[i]?.invitedName && table[i].invitedName != item)
          {
            local color = ""
            if (obj_tbl?.team) {
              if (obj_tbl.team == "red")
                color = "teamRedInactiveColor"
              else if (obj_tbl.team == "blue")
                color = "teamBlueInactiveColor"
            }

            local playerName = ::colorize(color, platformModule.getPlayerName(table[i].invitedName))
            nameText = $"{platformModule.getPlayerName(nameText)}... {playerName}"
          }
        }

        let objName = objTd.findObject("name-text")
        if (::check_obj(objName))
         objName.setValue(nameText)

        let objDlcImg = objTd.findObject("dlc-ico")
        if (::check_obj(objDlcImg))
          objDlcImg.show(false)

        local tooltip = nameText
        if (!isEmpty)
        {
          let isLocal = table[i].isLocal
          //isInMySquad check fixes lag of first 4 seconds, when code don't know about player in my squad.
          let isInHeroSquad = table[i]?.isInHeroSquad || ::SessionLobby.isMemberInMySquadByName(item)
          objTr.mainPlayer = isLocal ? "yes" : "no"
          objTr.inMySquad  = isInHeroSquad ? "yes" : "no"
          objTr.spectator = table[i]?.spectator ? "yes" : "no"

          let playerInfo = playersInfo?[(table[i].userId).tointeger()]
          if (!isLocal && isInHeroSquad && playerInfo?.auto_squad)
            tooltip = $"{tooltip}\n\n{::loc("squad/auto")}\n"

          if (!table[i].isBot
            && ::get_mission_difficulty() == ::g_difficulty.ARCADE.gameTypeName
            && !::g_mis_custom_state.getCurMissionRules().isWorldWar)
          {
            let data = ::SessionLobby.getBattleRatingParamByPlayerInfo(playerInfo)
            if (data)
            {
              let squadInfo = getSquadInfo(data.squad)
              let isInSquad = squadInfo ? !squadInfo.autoSquad : false
              let ratingTotal = ::calc_battle_rating_from_rank(data.rank)
              tooltip += "\n" + ::loc("debriefing/battleRating/units") + ::loc("ui/colon")
              local showLowBRPrompt = false

              let unitsForTooltip = []
              for (local j = 0; j < min(data.units.len(), 3); ++j)
                unitsForTooltip.append(data.units[j])
              unitsForTooltip.sort(sort_units_for_br_tooltip)
              for (local j = 0; j < unitsForTooltip.len(); ++j)
              {
                let rankUnused = unitsForTooltip[j].rankUnused
                let formatString = rankUnused
                  ? "\n<color=@disabledTextColor>(%.1f) %s</color>"
                  : "\n<color=@disabledTextColor>(<color=@userlogColoredText>%.1f</color>) %s</color>"
                if (rankUnused)
                  showLowBRPrompt = true
                tooltip += ::format(formatString, unitsForTooltip[j].rating, unitsForTooltip[j].name)
              }
              tooltip += "\n" + ::loc(isInSquad ? "debriefing/battleRating/squad" : "debriefing/battleRating/total") +
                                ::loc("ui/colon") + ::format("%.1f", ratingTotal)
              if (showLowBRPrompt)
              {
                let maxBRDifference = 2.0 // Hardcoded till switch to new matching.
                let rankCalcMode = ::SessionLobby.getRankCalcMode()
                if (rankCalcMode)
                  tooltip += "\n" + ::loc("multiplayer/lowBattleRatingPrompt/" + rankCalcMode, { maxBRDifference = ::format("%.1f", maxBRDifference) })
              }
            }
          }
        }
        objTr.tooltip = tooltip
      }
      else if (hdr == "unitIcon")
      {
        local unitIco = ""
        local unitIcoColorType = ""
        local unitId = ""
        local weapon = ""

        if (!isEmpty)
        {
          let player = table[i]
          if (isInFlight && !isInGame)
            unitIco = ::g_player_state.HAS_LEAVED_GAME.getIcon(player)
          else if (player?.isDead)
            unitIco = (player?.spectator) ? "#ui/gameuiskin#player_spectator.svg" : "#ui/gameuiskin#dead.svg"
          else if (showAirIcons && ("aircraftName" in player))
          {
            unitId = player.aircraftName
            unitIco = ::getUnitClassIco(unitId)
            unitIcoColorType = getUnitRole(unitId)
            weapon = player?.weapon ?? ""
          }
        }

        local obj = objTd.findObject("unit-ico")
        if (::check_obj(obj))
        {
          obj["background-image"] = unitIco
          obj["shopItemType"] = unitIcoColorType
        }

        foreach(iconId, icon in ::getWeaponTypeIcoByWeapon(unitId, weapon))
        {
          obj = objTd.findObject(iconId + "-ico")
          if (::check_obj(obj))
            obj["background-image"] = icon
        }
      }
      else if (hdr == "aircraft")
      {
        let objText = objTd.findObject("txt_aircraft")
        if (::checkObj(objText))
        {
          local text = ""
          local tooltip = ""
          if (!isEmpty)
          {
            if (::getTblValue("spectator", table[i], false))
            {
              text = ::loc("mainmenu/btnReferee")
              tooltip = ::loc("multiplayer/state/player_referee")
            }
            else
            {
              let unitId = !isEmpty ? ::getTblValue("aircraftName", table[i], "") : ""
              text = (unitId != "") ? ::loc(::getUnitName(unitId, true)) : "..."
              tooltip = (unitId != "") ? ::loc(::getUnitName(unitId, false)) : ""
            }
          }
          objText.setValue(text)
          objText.tooltip = tooltip
        }
      }
      else if (hdr == "rowNo")
      {
        let tablePos = i + 1
        let pos = tablePos + continueRowNum
        objTd.getChild(0).setValue(pos.tostring())
        local winPlace = "none"
        if (!isEmpty && numberOfWinningPlaces > 0 && ::getTblValue("raceLastCheckpoint", table[i], 0) > 0)
        {
          if (tablePos == 1)
            winPlace = "1st"
          else if (tablePos <= numberOfWinningPlaces)
            winPlace = "2nd"
        }
        objTr.winnerPlace = winPlace
      }
      else if (hdr == "place")
      {
        objTd.getChild(0).setValue(item)
      }
      else if (::isInArray(hdr, [ "aiTotalKills", "assists", "score", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        let paramType = isEmpty ? null : ::g_mplayer_param_type.getTypeById(hdr)
        let txt = paramType ? paramType.printFunc(item, table[i]) : ""
        let objText = objTd.getChild(0)
        objText.setValue(txt)
        objText.tooltip = paramType ? paramType.getTooltip(item, table[i], txt) : ""
      }
      else if (hdr == "numPlayers")
      {
        local txt = item.tostring()
        if (!isEmpty && "numPlayersTotal" in table[i])
          txt += "/" + table[i].numPlayersTotal
        objTd.getChild(0).setValue(txt)
      }
      else if (hdr == "squad")
      {
        let squadInfo = (!isEmpty && isShowSquad()) ? getSquadInfoByMemberName(table[i]?.name ?? "") : null
        let squadId = ::getTblValue("squadId", squadInfo, INVALID_SQUAD_ID)
        let labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        let needSquadIcon = labelSquad != ""
        let squadScore = needSquadIcon ? ::getTblValue("squadScore", table[i], 0) : 0
        let isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == getTopSquadId(squadInfo.teamId)

        let cellText = objTd.findObject("txt_"+hdr)
        if (::checkObj(cellText))
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")

        let cellIcon = objTd.findObject("icon_"+hdr)
        if (::checkObj(cellIcon))
        {
          cellIcon.show(needSquadIcon)
          if (needSquadIcon)
          {
            cellIcon["iconSquad"] = squadInfo.autoSquad ? "autosquad" : "squad"
            cellIcon["topSquad"] = isTopSquad ? "yes" : "no"
            cellIcon["tooltip"] = ::format("%s %s%s", ::loc("options/chat_messages_squad"), ::loc("ui/number_sign", "#"), labelSquad)
              + "\n" + ::loc("profile/awards") + ::loc("ui/colon") + squadScore
              + (isTopSquad ? ("\n" + ::loc("streaks/squad_best")) : "")

            if (isReplay)
              objTd.team = squadInfo.teamId == ::get_player_army_for_hud() ? "blue" : "red"
          }
        }
      }
      else
      {
        local txt = item.tostring()
        if (txt.len() > 0 && txt[0] == '#')
          txt = ::loc(txt.slice(1))
        let objText = objTd.findObject("txt_"+hdr)
        if (objText)
        {
          objText.setValue(txt)
          objText.tooltip = txt
        }
      }
    }
  }
}

::sort_units_for_br_tooltip <- function sort_units_for_br_tooltip(u1, u2)
{
  if (u1.rating != u2.rating)
    return u1.rating > u2.rating ? -1 : 1
  if (u1.rankUnused != u2.rankUnused)
    return u1.rankUnused ? 1 : -1
  return 0
}

::getCurMpTitle <- function getCurMpTitle()
{
  local text = ""

  if (::g_mis_custom_state.getCurMissionRules().isWorldWar && ::is_worldwar_enabled())
  {
    text = ::g_world_war.getCurMissionWWOperationName()
    let battleInfoText = ::g_world_war.getCurMissionWWBattleName()
    text += ((text.len() && battleInfoText.len()) ? ::loc("ui/comma") : "") + battleInfoText
  }
  else
  {
    let gm = ::get_game_mode()
    if (gm == ::GM_DOMINATION)
    {
      let diffCode = ::get_mission_difficulty_int()
      text = ::g_difficulty.getDifficultyByDiffCode(diffCode).getLocName()
    }
    else if (gm==::GM_SKIRMISH)         text = ::loc("multiplayer/skirmishMode")
    else if (gm==::GM_CAMPAIGN)         text = ::loc("mainmenu/btnCampaign")
    else if (gm==::GM_SINGLE_MISSION)   text = ::loc("mainmenu/btnCoop")
    else if (gm==::GM_DYNAMIC)          text = ::loc("mainmenu/btnDynamic")
    else if (gm==::GM_BUILDER)          text = ::loc("mainmenu/btnBuilder")
    //else if (gm==::GM_TOURNAMENT)       text = ::loc("multiplayer/tournamentMode")

    text += ((text.len()) ? ::loc("ui/comma") : "") + ::loc_current_mission_name()
  }

  return text
}

::getUnitClassIco <- function getUnitClassIco(unit)
{
  if (::u.isString(unit))
    unit = ::getAircraftByName(unit)
  if (!unit)
    return ""
  return unit.customClassIco ?? ::get_unit_class_icon_by_unit(unit, unit.name + "_ico")
}

::getUnitClassColor <- function getUnitClassColor(unit)
{
  let role = getUnitRole(unit) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  if (role == null || role == "" || role == "none")
    return "white";
  return role + "Color"
}

::getWeaponTypeIcoByWeapon <- function getWeaponTypeIcoByWeapon(airName, weapon, tankWeapons = false)
{
  let config = {bomb = "", rocket = "", torpedo = "", additionalGuns = ""}
  let air = getAircraftByName(airName)
  if (!air) return config

  foreach(w in air.getWeapons())
    if (w.name == weapon)
    {
      let tankRockets = tankWeapons && (w?[WEAPON_TAG.ANTI_TANK_ROCKET] ||
        w?[WEAPON_TAG.ANTI_SHIP_ROCKET])
      config.bomb = w.bomb? "#ui/gameuiskin#weap_bomb.svg" : ""
      config.rocket = w.rocket || tankRockets? "#ui/gameuiskin#weap_missile.svg" : ""
      config.torpedo = w.torpedo? "#ui/gameuiskin#weap_torpedo.svg" : ""
      config.additionalGuns = w.additionalGuns ? "#ui/gameuiskin#weap_pod.svg" : ""
      break
    }
  return config
}

::get_weapon_icons_text <- function get_weapon_icons_text(unitName, weaponName)
{
  if (!weaponName || ::u.isEmpty(weaponName))
    return ""

  let unit = getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponIconsText = ""
  foreach(weapon in unit.getWeapons())
    if (weapon.name == weaponName)
    {
      foreach (paramName in [WEAPON_TAG.BOMB, WEAPON_TAG.ROCKET,
        WEAPON_TAG.TORPEDO, WEAPON_TAG.ADD_GUN])
          if (weapon[paramName])
            weaponIconsText += ::loc("weapon/" + paramName + "Icon")
      break
    }

  return ::colorize("weaponPresetColor", weaponIconsText)
}

::get_mp_country_by_team <- function get_mp_country_by_team(team)
{
  let info = ::get_mp_session_info()
  if (!info)
    return ""
  if (team==1 && ("alliesCountry" in info))
    return "country_"+info.alliesCountry
  if (team==2 && ("axisCountry" in info))
    return "country_"+info.axisCountry
  return "country_0"
}

::count_width_for_mptable <- function count_width_for_mptable(objTbl, markup)
{
  let guiScene = objTbl.getScene()
  local usedWidth = 0
  local relWidthTotal = 0.0
  foreach (id, col in markup)
  {
    if ("relWidth" in col)
      relWidthTotal += col.relWidth
    else if ("width" in col)
    {
      let width = guiScene.calcString(col.width, objTbl)
      col.width = width.tostring()
      usedWidth += width
    }
  }

  local freeWidth = objTbl.getSize()[0] - usedWidth
  foreach (id, col in markup)
  {
    if (relWidthTotal > 0 && ("relWidth" in col))
    {
      let width = (freeWidth * col.relWidth / relWidthTotal).tointeger()
      col.width <- width.tostring()
      freeWidth -= width
      relWidthTotal -= col.relWidth
      delete col.relWidth
    }
  }
}

return {
  guiStartMPStatScreen
  guiStartMPStatScreenFromGame
}