local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")
local spectatorWatchedHero = require("scripts/replays/spectatorWatchedHero.nut")
local mpChatModel = require("scripts/chat/mpChatModel.nut")
local avatars = require("scripts/user/avatars.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
local { WEAPON_TAG } = require("scripts/weaponry/weaponryInfo.nut")

const OVERRIDE_COUNTRY_ID = "override_country"

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
  return (team ?? ::get_mp_local_team()) != Team.B ? Team.A : Team.B
}

::gui_start_mpstatscreen_ <- function gui_start_mpstatscreen_(is_from_game)
{
  local handler = ::handlersManager.loadHandler(::gui_handlers.MPStatScreen,
                    { backSceneFunc = is_from_game? null : ::handlersManager.getLastBaseHandlerStartFunc(),
                      isFromGame = is_from_game
                    })
  if (is_from_game)
    ::statscreen_handler = handler
}

::gui_start_mpstatscreen <- function gui_start_mpstatscreen()
{
  gui_start_mpstatscreen_(false)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mpstatscreen)
}

::gui_start_mpstatscreen_from_game <- function gui_start_mpstatscreen_from_game()
{
  gui_start_mpstatscreen_(true)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mpstatscreen_from_game)
}

::gui_start_flight_menu_stat <- function gui_start_flight_menu_stat()
{
  gui_start_mpstatscreen_from_game()
}

::is_mpstatscreen_active <- function is_mpstatscreen_active()
{
  if (!::g_login.isLoggedIn())
    return false
  local curHandler = ::handlersManager.getActiveBaseHandler()
  return curHandler != null && (curHandler instanceof ::gui_handlers.MPStatScreen)
}

::build_mp_table <- function build_mp_table(table, markupData, hdr, max_rows)
{
  local numTblRows = table.len()
  local numRows = ::max(numTblRows, max_rows)
  if (numRows <= 0)
    return ""

  local isHeader    = markupData?.is_header ?? false
  local trSize      = markupData?.tr_size   ?? "pw, @baseTrHeight"
  local isRowInvert = markupData?.invert    ?? false
  local colorTeam   = markupData?.colorTeam ?? "blue"

  local markup = markupData.columns

  if (isRowInvert)
  {
    hdr = clone hdr
    hdr.reverse()
  }

  local data = ""
  for (local i = 0; i < numRows; i++)
  {
    local isEmpty = i >= numTblRows
    local trData = format("even:t='%s'; ", (i%2 == 0)? "yes" : "no")
    local trAdd = isEmpty? "inactive:t='yes'; " : ""

    for (local j = 0; j < hdr.len(); ++j)
    {
      local item = ""
      local tdData = ""
      local widthAdd = ((j==0)||(j==(hdr.len()-1)))? "+@tablePad":""
      local textPadding = "style:t='padding:0.005sh,0;'; "
      if (j==0)             textPadding = "style:t='padding:@tablePad,0,0.005sh,0;'; "
      if (j==(hdr.len()-1)) textPadding = "style:t='padding:0.005sh,0,@tablePad,0;'; "

      if (!isEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] == "hasPassword")
      {
        local icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData += "size:t='ph"+widthAdd+" ,ph';"  +
          ("img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';" +
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='" + (isEmpty ? "" : icon) + "'; }")
      }
      else if (hdr[j] == "team")
      {
        local teamText = "teamImg{ text { halign:t='center'}} "
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

        if (!isHeader && !isEmpty && !table?[i].isBot)
          nameText = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(nameText), table[i].clanTag ?? "")

        local nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        local nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData += format ("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s';" +
          "pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s",
          nameWidth, "textareaNoTab", nameAlign, nameText, textPadding
        )

        if (!isEmpty)
        {
          if (("isLocal" in table[i]) && table[i].isLocal)
            trAdd += "mainPlayer:t = 'yes';"
          else if (("isInHeroSquad" in table[i]) && table[i].isInHeroSquad)
            trAdd += "inMySquad:t = 'yes';"
          if (("spectator" in table[i]) && table[i].spectator)
            trAdd += "spectator:t = 'yes';"
        }
      }
      else if (hdr[j] == "unitIcon")
      {
        //creating empty unit class/dead icon and weapons icons, to be filled in update func
        local images = [ "img { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-svg-size:t='@tableIcoSize, @tableIcoSize'; background-image:t=''; background-repeat:t='aspect-ratio'; shopItemType:t=''; }" ]
        foreach(id, weap in ::getWeaponTypeIcoByWeapon("", ""))
          images.insert(0, ::format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-svg-size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0' }", id))
        if (isRowInvert)
          images.reverse()
        local cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        local divPos = isRowInvert ? "0" : "pw-w"
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
        local rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        local prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        local cell = isRowInvert ? prestigeItem + rankItem : rankItem + prestigeItem
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
        local width = "width:t='" + ::getTblValue("width", markup[hdr[j]], "1") + "'; "
        tdData += ::format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (::isInArray(hdr[j], [ "aiTotalKills", "assists", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        local txt = isEmpty ? "" : ::g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData += ::format("activeText { text:t='%s' halign:t='center' } ", txt)
        local width = ::getTblValue("width", ::getTblValue(hdr[j], markup, {}), "")
        if (width != "")
          tdData += ::format("width:t='%s'; ", width)
      }
      else if (hdr[j] == "numPlayers")
      {
        local curWidth = ((hdr[j] in markup)&&("width" in markup[hdr[j]]))?markup[hdr[j]].width:"0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isEmpty && "numPlayersTotal" in table[i])
        {
          local maxVal = table[i].numPlayersTotal
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
        local text = ::locOrStrip(item.tostring())
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
        local textParams = format("halign:t='%s'; ", halign)

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
  local teamCode = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team
    : (customPlayerTeam ?? ::get_local_team_for_mpstats())
  nestObj.playerTeam = ::g_team.getTeamByCode(teamCode).cssLabel
}

::set_mp_table <- function set_mp_table(obj_tbl, table, params)
{
  local max_rows = ::getTblValue("max_rows", params, 0)
  local numTblRows = table.len()
  local numRows = numTblRows > max_rows ? numTblRows : max_rows
  local realTblRows = obj_tbl.childrenCount()

  if ((numRows <= 0)||(realTblRows <= 0))
    return

  local showAirIcons = ::getTblValue("showAirIcons", params, true)
  local continueRowNum = ::getTblValue("continueRowNum", params, 0)
  local numberOfWinningPlaces = ::getTblValue("numberOfWinningPlaces", params, -1)
  local playersInfo = params?.playersInfo ?? ::SessionLobby.getPlayersInfo()
  local isInFlight = ::is_in_flight()
  local needColorizeNotInGame = isInFlight
  local isReplay = ::is_replay_playing()

  ::SquadIcon.updateTopSquadScore(table)

  for (local i = 0; i < numRows; i++)
  {
    local objTr = null
    if (realTblRows <= i)
      objTr = obj_tbl.getChild(realTblRows-1).getClone()
    else
      objTr = obj_tbl.getChild(i)

    local isEmpty = i >= numTblRows
    objTr.inactive = isEmpty? "yes" : "no"
    objTr.show(!isEmpty || i < max_rows)
    if (i >= numRows)
      continue

    local isInGame = true
    if (!isEmpty && needColorizeNotInGame)
    {
      local state = table[i].state
      isInGame = state == ::PLAYER_IN_FLIGHT || state == ::PLAYER_IN_RESPAWN
      objTr.inGame = isInGame ? "yes" : "no"
    }

    local totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++)
    {
      local objTd = objTr.getChild(idx)
      local id = objTd?.id
      if (!id || id.len()<4 || id.slice(0, 3)!="td_")
        continue

      local hdr = id.slice(3)
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

        local objImg = objTd.getChild(0)
        local icon = ""
        if (!isEmpty && country != "")
          icon = ::get_country_icon(country)
        objImg["background-image"] = icon
      }
      else if (hdr == "status")
      {
        local objReady = objTd.findObject("ready-ico")
        if (::check_obj(objReady))
        {
          if (isEmpty)
            objReady["background-image"] = ""
          else
          {
            local playerState = ::g_player_state.getStateByPlayerInfo(table[i])
            objReady["background-image"] = playerState.getIcon(table[i])
            objReady["background-color"] = playerState.getIconColor()
            local desc = playerState.getText(table[i])
            objReady.tooltip = (desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : ""
          }
        }
      }
      else if (hdr == "name")
      {
        local nameText = item

        if (!isEmpty)
        {
          if (!table?[i].isBot)
            nameText = ::g_contacts.getPlayerFullName(platformModule.getPlayerName(item), table[i]?.clanTag ?? "")

          if (("invitedName" in table[i]) && table[i].invitedName != item)
          {
            local color = ""
            if (obj_tbl?.team)
              if (obj_tbl.team == "red")
                color = "teamRedInactiveColor"
              else if (obj_tbl.team == "blue")
                color = "teamBlueInactiveColor"

            local playerName = ::colorize(color, platformModule.getPlayerName(table[i].invitedName))
            nameText = ::format("%s... %s", platformModule.getPlayerName(nameText), playerName)
          }
        }

        local objName = objTd.findObject("name-text")
        if (::check_obj(objName))
         objName.setValue(nameText)

        local objDlcImg = objTd.findObject("dlc-ico")
        if (::check_obj(objDlcImg))
          objDlcImg.show(false)

        local tooltip = nameText
        if (!isEmpty)
        {
          objTr.mainPlayer = table[i].isLocal ? "yes" : "no"
          objTr.inMySquad  = table[i]?.isInHeroSquad ? "yes" : "no"
          objTr.spectator = (("spectator" in table[i]) && table[i].spectator) ? "yes" : "no"

          if (!table[i].isBot
            && ::get_mission_difficulty() == ::g_difficulty.ARCADE.gameTypeName
            && !::g_mis_custom_state.getCurMissionRules().isWorldWar)
          {
            local data = ::SessionLobby.getBattleRatingParamByPlayerInfo(playersInfo?[(table[i].userId).tointeger()])
            if (data)
            {
              local squadInfo = ::SquadIcon.getSquadInfo(data.squad)
              local isInSquad = squadInfo ? !squadInfo.autoSquad : false
              local ratingTotal = ::calc_battle_rating_from_rank(data.rank)
              tooltip += "\n" + ::loc("debriefing/battleRating/units") + ::loc("ui/colon")
              local showLowBRPrompt = false

              local unitsForTooltip = []
              for (local j = 0; j < min(data.units.len(), 3); ++j)
                unitsForTooltip.append(data.units[j])
              unitsForTooltip.sort(sort_units_for_br_tooltip)
              for (local j = 0; j < unitsForTooltip.len(); ++j)
              {
                local rankUnused = unitsForTooltip[j].rankUnused
                local formatString = rankUnused
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
                local maxBRDifference = 2.0 // Hardcoded till switch to new matching.
                local rankCalcMode = ::SessionLobby.getRankCalcMode()
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
          local player = table[i]
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
        local objText = objTd.findObject("txt_aircraft")
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
              local unitId = !isEmpty ? ::getTblValue("aircraftName", table[i], "") : ""
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
        local tablePos = i + 1
        local pos = tablePos + continueRowNum
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
      else if (::isInArray(hdr, [ "aiTotalKills", "assists", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        local paramType = isEmpty ? null : ::g_mplayer_param_type.getTypeById(hdr)
        local txt = paramType ? paramType.printFunc(item, table[i]) : ""
        local objText = objTd.getChild(0)
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
        local squadInfo = (!isEmpty && ::SquadIcon.isShowSquad()) ? ::SquadIcon.getSquadInfoByMemberName(::getTblValue("name", table[i], "")) : null
        local squadId = ::getTblValue("squadId", squadInfo, INVALID_SQUAD_ID)
        local labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        local needSquadIcon = labelSquad != ""
        local squadScore = needSquadIcon ? ::getTblValue("squadScore", table[i], 0) : 0
        local isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == ::SquadIcon.getTopSquadId(squadInfo.teamId)

        local cellText = objTd.findObject("txt_"+hdr)
        if (::checkObj(cellText))
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")

        local cellIcon = objTd.findObject("icon_"+hdr)
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
        local objText = objTd.findObject("txt_"+hdr)
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

  if (::g_mis_custom_state.getCurMissionRules().isWorldWar)
  {
    text = ::g_world_war.getCurMissionWWOperationName()
    local battleInfoText = ::g_world_war.getCurMissionWWBattleName()
    text += ((text.len() && battleInfoText.len()) ? ::loc("ui/comma") : "") + battleInfoText
  }
  else
  {
    local gm = ::get_game_mode()
    if (gm == ::GM_DOMINATION)
    {
      local diffCode = ::get_mission_difficulty_int()
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
  local role = getUnitRole(unit) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  if (role == null || role == "" || role == "none")
    return "white";
  return role + "Color"
}

::getWeaponTypeIcoByWeapon <- function getWeaponTypeIcoByWeapon(airName, weapon, tankWeapons = false)
{
  local config = {bomb = "", rocket = "", torpedo = "", additionalGuns = ""}
  local air = getAircraftByName(airName)
  if (!air) return config

  foreach(w in air.weapons)
    if (w.name == weapon)
    {
      local tankRockets = tankWeapons && (w?[WEAPON_TAG.ANTI_TANK_ROCKET] ||
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

  local unit = getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponIconsText = ""
  foreach(weapon in unit.weapons)
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
  local info = ::get_mp_session_info()
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
  local guiScene = objTbl.getScene()
  local usedWidth = 0
  local relWidthTotal = 0.0
  foreach (id, col in markup)
  {
    if ("relWidth" in col)
      relWidthTotal += col.relWidth
    else if ("width" in col)
    {
      local width = guiScene.calcString(col.width, objTbl)
      col.width = width.tostring()
      usedWidth += width
    }
  }

  local freeWidth = objTbl.getSize()[0] - usedWidth
  foreach (id, col in markup)
  {
    if (relWidthTotal > 0 && ("relWidth" in col))
    {
      local width = (freeWidth * col.relWidth / relWidthTotal).tointeger()
      col.width <- width.tostring()
      freeWidth -= width
      relWidthTotal -= col.relWidth
      delete col.relWidth
    }
  }
}

class ::gui_handlers.MPStatistics extends ::gui_handlers.BaseGuiHandlerWT
{
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                         | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY

  needPlayersTbl = true
  showLocalTeamOnly = false
  isModeStat = false
  isRespawn = false
  isSpectate = false
  isTeam = false
  isStatScreen = true

  isWideScreenStatTbl = false
  showAircrafts = false

  mplayerTable = null
  missionTable = null

  tblSave1 = null
  numRows1 = 0
  tblSave2 = null
  numRows2 = 0

  gameMode = 0
  gameType = 0
  isOnline = false

  isTeamplay    = false
  isTeamsWithCountryFlags = false
  isTeamsRandom = true

  missionObjectives = MISSION_OBJECTIVE.NONE

  wasTimeLeft = -1000
  updateCooldown = 3

  numMaxPlayers = 16  //its only visual max players. no need to scroll when table near empty.
  isApplyPressed = false

  checkRaceDataOnStart = true
  numberOfWinningPlaces = -1

  defaultRowHeaders         = ["squad", "name", "unitIcon", "aircraft", "missionAliveTime", "score", "kills", "groundKills", "navalKills",
                               "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "awardDamage", "assists", "captureZone", "damageZone", "deaths"]
  raceRowHeaders            = ["rowNo", "name", "unitIcon", "aircraft", "raceFinishTime", "raceLap", "raceLastCheckpoint",
                               "raceLastCheckpointTime", "deaths"]
  footballRowHeaders        = ["name", "footballScore", "footballGoals", "footballAssists"]

  statTrSize = "pw, 1@baseTrHeight"

  function onActivateOrder()
  {
    ::g_orders.openOrdersInventory(true)
  }

  function updateTimeToKick(dt)
  {
    updateTimeToKickTimer()
    updateTimeToKickAlert(dt)
  }

  function updateTimeToKickTimer()
  {
    local timeToKickObj = getTimeToKickObj()
    if (!::checkObj(timeToKickObj))
      return
    local timeToKickValue = ::get_mp_kick_countdown()
    // Already in battle or it's too early to show the message.
    if (timeToKickValue <= 0 || ::get_time_to_kick_show_timer() < timeToKickValue)
      timeToKickObj.setValue("")
    else
    {
      local timeToKickText = time.secondsToString(timeToKickValue, true, true)
      local locParams = {
        timeToKick = ::colorize("activeTextColor", timeToKickText)
      }
      timeToKickObj.setValue(::loc("respawn/timeToKick", locParams))
    }
  }

  function updateTimeToKickAlert(dt)
  {
    local timeToKickAlertObj = scene.findObject("time_to_kick_alert_text")
    if (!::checkObj(timeToKickAlertObj))
      return
    local timeToKickValue = ::get_mp_kick_countdown()
    if (timeToKickValue <= 0 || get_time_to_kick_show_alert() < timeToKickValue || isSpectate)
      timeToKickAlertObj.show(false)
    else
    {
      timeToKickAlertObj.show(true)
      local curTime = ::dagor.getCurTime()
      local prevSeconds = ((curTime - 1000 * dt) / 1000).tointeger()
      local currSeconds = (curTime / 1000).tointeger()
      if (currSeconds != prevSeconds)
      {
        timeToKickAlertObj["_blink"] = "yes"
        guiScene.playSound("kick_alert")
      }
    }
  }

  function onOrderTimerUpdate(obj, dt)
  {
    ::g_orders.updateActiveOrder()
    if (::checkObj(obj))
    {
      obj.text = ::g_orders.getActivateButtonLabel()
      obj.inactiveColor = !::g_orders.orderCanBeActivated() ? "yes" : "no"
    }
  }

  function setTeamInfoTeam(teamObj, team)
  {
    if (!::checkObj(teamObj))
      return
    teamObj.team = team
  }

  function setTeamInfoTeamIco(teamObj, teamIco = null)
  {
    if (!::checkObj(teamObj))
      return
    local teamImgObj = teamObj.findObject("team_img")
    if (::checkObj(teamImgObj))
      teamImgObj.show(teamIco != null)
    if (teamIco != null)
      teamObj.teamIco = teamIco
  }

  function setTeamInfoText(teamObj, text)
  {
    if (!::checkObj(teamObj))
      return
    local textObj = teamObj.findObject("team_text")
    if (::checkObj(textObj))
      textObj.setValue(text)
  }

  /**
   * Sets country flags visibility based
   * on specified country names list.
   */
  function setTeamInfoCountries(teamObj, enabledCountryNames)
  {
    if (!::checkObj(teamObj))
      return
    foreach (countryName in ::shopCountriesList)
    {
      local countryFlagObj = teamObj.findObject(countryName)
      if (::checkObj(countryFlagObj))
        countryFlagObj.show(::isInArray(countryName, enabledCountryNames))
    }
  }

  function updateOverrideCountry(teamObj, countryIcon) {
    if (!::check_obj(teamObj))
      return

    local countryFlagObj = ::showBtn(OVERRIDE_COUNTRY_ID, countryIcon != null, teamObj)
    if (::check_obj(countryFlagObj))
      countryFlagObj["background-image"] = ::get_country_icon(countryIcon)
  }

  /**
   * Places all available country
   * flags into container.
   */
  function initTeamInfoCountries(teamObj)
  {
    if (!::checkObj(teamObj))
      return
    local countriesBlock = teamObj.findObject("countries_block")
    if (!::checkObj(countriesBlock))
      return
    local view = {
      countries = ::shopCountriesList
        .map(@(countryName) {
          countryName = countryName
          countryIcon = ::get_country_icon(countryName)
        })
        .append({
          countryName = OVERRIDE_COUNTRY_ID
          countryIcon = ""
        })
    }
    local result = ::handyman.renderCached("gui/countriesList", view)
    guiScene.replaceContentFromText(countriesBlock, result, result.len(), this)
  }

  function setInfo()
  {
    local timeLeft = ::get_multiplayer_time_left()
    if (timeLeft < 0)
    {
      setGameEndStat(-1)
      return
    }
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
  }

  function initScreen()
  {
    scene.findObject("stat_update").setUserData(this)
    needPlayersTbl = scene.findObject("table_kills_team1") != null

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    setInfo()
  }

  function initStats()
  {
    if (!::checkObj(scene))
      return

    initStatsMissionParams()

    local playerTeam = getLocalTeam()
    local friendlyTeam = ::get_player_army_for_hud()
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")

    if (!isTeamplay)
    {
      foreach(obj in [teamObj1, teamObj2])
        if (::checkObj(obj))
          obj.show(false)
    }
    else if (needPlayersTbl && playerTeam > 0)
    {
      if (::checkObj(teamObj1))
      {
        setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam)? "blue" : "red")
        initTeamInfoCountries(teamObj1)
      }
      if (!showLocalTeamOnly && ::checkObj(teamObj2))
      {
        setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        initTeamInfoCountries(teamObj2)
      }
    }

    if (needPlayersTbl)
    {
      createStats()
      scene.findObject("table_kills_team1").setValue(-1)
      scene.findObject("table_kills_team2").setValue(-1)
    }

    updateCountryFlags()
  }

  function initStatsMissionParams()
  {
    gameMode = ::get_game_mode()
    gameType = ::get_game_type()
    isOnline = ::g_login.isLoggedIn()

    isTeamplay = ::is_mode_with_teams(gameType)
    isTeamsRandom = !isTeamplay || gameMode == ::GM_DOMINATION
    if (::SessionLobby.isInRoom() || ::is_replay_playing())
      isTeamsWithCountryFlags = isTeamplay &&
        (::get_mission_difficulty_int() > 0 || !::SessionLobby.getPublicParam("symmetricTeams", true))

    missionObjectives = ::g_mission_type.getCurrentObjectives()
  }

  function createKillsTbl(objTbl, tbl, tblConfig)
  {
    local team = ::getTblValue("team", tblConfig, -1)
    local num_rows = ::getTblValue("num_rows", tblConfig, numMaxPlayers)
    local showUnits     = tblConfig?.showAircrafts ?? false
    local showAirIcons  = tblConfig?.showAirIcons  ?? showUnits
    local invert = ::getTblValue("invert", tblConfig, false)

    local tblData = [] // columns order

    local markupData = {
      tr_size = statTrSize
      invert = invert
      colorTeam = "blue"
      columns = {}
    }

    if (gameType & ::GT_COOPERATIVE)
    {
      tblData = showAirIcons ? [ "unitIcon", "name" ] : [ "name" ]
      foreach(id in tblData)
        markupData.columns[id] <- ::g_mplayer_param_type.getTypeById(id).getMarkupData()

      if ("name" in markupData.columns)
        markupData.columns["name"].width = "fw"
    }
    else
    {
      local sourceHeaders = gameType & ::GT_FOOTBALL ? footballRowHeaders
        : gameType & ::GT_RACE ? raceRowHeaders
        : defaultRowHeaders

      foreach (id in sourceHeaders)
        if (::g_mplayer_param_type.getTypeById(id).isVisible(missionObjectives, gameType, gameMode))
          tblData.append(id)

      if (!showUnits)
        ::u.removeFrom(tblData, "aircraft")
      if (!::SquadIcon.isShowSquad())
        ::u.removeFrom(tblData, "squad")

      foreach(name in tblData)
        markupData.columns[name] <- ::g_mplayer_param_type.getTypeById(name).getMarkupData()

      if ("name" in markupData.columns)
      {
        local col = markupData.columns["name"]
        if (isWideScreenStatTbl && ("widthInWideScreen" in col))
          col.width = col.widthInWideScreen
      }

      ::count_width_for_mptable(objTbl, markupData.columns)

      local teamNum = (team==2)? 2 : 1
      local tableObj = scene.findObject("team_table_" + teamNum)
      if (team == 2)
        markupData.colorTeam = "red"
      if (::checkObj(tableObj))
      {
        local rowHeaderData = createHeaderRow(tableObj, tblData, markupData, teamNum)
        local show = rowHeaderData != ""
        guiScene.replaceContentFromText(tableObj, rowHeaderData, rowHeaderData.len(), this)
        tableObj.show(show)
        tableObj.normalFont = ::is_low_width_screen() ? "yes" : "no"
      }
    }

    if (team == -1 || team == 1)
      tblSave1 = tbl
    else
      tblSave2 = tbl

    if (tbl)
    {
      if (!isTeamplay)
        sortTable(tbl)

      local data = ::build_mp_table(tbl, markupData, tblData, num_rows)
      guiScene.replaceContentFromText(objTbl, data, data.len(), this)
    }
  }

  function sortTable(table)
  {
    table.sort(::mpstat_get_sort_func(gameType))
  }

  function setKillsTbl(objTbl, team, playerTeam, friendlyTeam, showAirIcons=true, customTbl = null)
  {
    if (!::checkObj(objTbl))
      return

    local tbl = null

    objTbl.smallFont = ::is_low_width_screen() ? "yes" : "no"

    if (customTbl)
    {
      local idx = max(team-1, -1)
      if (idx in customTbl?.playersTbl)
        tbl = customTbl.playersTbl[idx]
    }

    local minRow = 0
    if (!tbl)
    {
      if (!isTeamplay)
      {
        local commonTbl = getMplayersList(::GET_MPLAYERS_LIST)
        sortTable(commonTbl)
        if (commonTbl.len() > 0)
        {
          local lastRow = numMaxPlayers - 1
          if (objTbl.id == "table_kills_team2")
          {
            minRow = commonTbl.len() <= numMaxPlayers ? 0 : numMaxPlayers
            lastRow = commonTbl.len()
          }

          tbl = []
          for(local i = lastRow; i >= minRow; --i)
          {
            if (!(i in commonTbl))
              continue

            local block = commonTbl.remove(i)
            block.place <- (i+1).tostring()
            tbl.append(block)
          }
          tbl.reverse()
        }
      }
      else
        tbl = getMplayersList(team)
    }
    else if (!isTeamplay && customTbl && objTbl.id == "table_kills_team2")
      minRow = numMaxPlayers

    if (objTbl.id == "table_kills_team2")
    {
      local shouldShow = true
      if (isTeamplay)
        shouldShow = tbl && tbl.len() > 0
      showSceneBtn("team2-root", shouldShow)
    }

    if (!isTeamplay && minRow >= 0)
    {
      if (minRow == 0)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }
    else
    {
      if (team == playerTeam || playerTeam == -1 || showLocalTeamOnly)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }

    if (tbl != null)
    {
      if (!customTbl && isTeamplay)
        sortTable(tbl)

      local numRows = numRows1
      if (team == 2)
        numRows = numRows2

      local params = {
                       max_rows = numRows,
                       showAirIcons = showAirIcons,
                       continueRowNum = minRow,
                       numberOfWinningPlaces = numberOfWinningPlaces
                       playersInfo = customTbl?.playersInfo
                     }
      ::set_mp_table(objTbl, tbl, params)
      ::update_team_css_label(objTbl, getLocalTeam())

      if (friendlyTeam > 0 && team > 0)
        objTbl["team"] = (isTeamplay && friendlyTeam == team)? "blue" : "red"
    }
    updateCountryFlags()
  }

  function isShowEnemyAirs()
  {
    return showAircrafts && ::get_mission_difficulty_int() == 0
  }

  function createStats()
  {
    if (!needPlayersTbl)
      return

    local tblObj1 = scene.findObject("table_kills_team1")
    local tblObj2 = scene.findObject("table_kills_team2")
    local team1Root = scene.findObject("team1-root")
    updateNumMaxPlayers()

    if (!isTeamplay)
    {
      local tbl1 = getMplayersList(::GET_MPLAYERS_LIST)
      sortTable(tbl1)

      local tbl2 = []
      numRows1 = tbl1.len()
      numRows2 = 0
      if (tbl1.len() >= numMaxPlayers)
      {
        numRows1 = numMaxPlayers
        numRows2 = numMaxPlayers

        for(local i = tbl1.len()-1; i >= numMaxPlayers; --i)
        {
          if (!(i in tbl1))
            continue

          local block = tbl1.remove(i)
          block.place <- (i+1).tostring()
          tbl2.append(block)
        }
        tbl2.reverse()
      }

      createKillsTbl(tblObj1, tbl1, {num_rows = numRows1, team = Team.A, showAircrafts = showAircrafts})
      createKillsTbl(tblObj2, tbl2, {num_rows = numRows2, team = Team.B, showAircrafts = showAircrafts})

      if (::checkObj(team1Root))
        team1Root.show(true)
    }
    else if (gameType & ::GT_VERSUS)
    {
      if (showLocalTeamOnly)
      {
        local playerTeam = getLocalTeam()
        local tbl = getMplayersList(playerTeam)
        numRows1 = numMaxPlayers
        numRows2 = 0
        createKillsTbl(tblObj1, tbl, {num_rows = numRows1, showAircrafts = showAircrafts})
      }
      else
      {
        local tbl1 = getMplayersList(1)
        local tbl2 = getMplayersList(2)
        local num_in_one_row = ::global_max_players_versus / 2
        if (tbl1.len() <= num_in_one_row && tbl2.len() <= num_in_one_row)
        {
          numRows1 = num_in_one_row
          numRows2 = num_in_one_row
        }
        else if (tbl1.len() > num_in_one_row)
          numRows2 = ::global_max_players_versus - tbl1.len()
        else if (tbl2.len() > num_in_one_row)
          numRows1 = ::global_max_players_versus - tbl2.len()

        if (numRows1 > numMaxPlayers)
          numRows1 = numMaxPlayers
        if (numRows2 > numMaxPlayers)
          numRows2 = numMaxPlayers

        local showEnemyAircrafts = isShowEnemyAirs()
        local tblConfig1 = {tbl = tbl2, team = Team.A, num_rows = numRows2, showAircrafts = showAircrafts, invert = true}
        local tblConfig2 = {tbl = tbl1, team = Team.B, num_rows = numRows1, showAircrafts = showEnemyAircrafts}

        if (getLocalTeam() == Team.A)
        {
          tblConfig1.tbl = tbl1
          tblConfig1.num_rows = numRows1

          tblConfig2.tbl = tbl2
          tblConfig2.num_rows = numRows2
        }

        createKillsTbl(tblObj1, tblConfig1.tbl, tblConfig1)
        createKillsTbl(tblObj2, tblConfig2.tbl, tblConfig2)

        if (::checkObj(team1Root))
          team1Root.show(true)
      }
    }
    else
    {
      numRows1 = (gameType & ::GT_COOPERATIVE)? ::global_max_players_coop : numMaxPlayers
      numRows2 = 0
      local tbl = getMplayersList(::GET_MPLAYERS_LIST)
      createKillsTbl(tblObj2, tbl, {num_rows = numRows1, showAircrafts = showAircrafts})

      tblObj1.show(false)

      if (::checkObj(team1Root))
        team1Root.show(false)

      local headerObj = scene.findObject("team2_header")
      if (::checkObj(headerObj))
        headerObj.show(false)
    }
  }

  function updateTeams(tbl, playerTeam, friendlyTeam)
  {
    if (!tbl)
      return

    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")

    local playerTeamIdx = ::clamp(playerTeam - 1, 0, 1)
    local teamTxt = ["", ""]
    switch (gameType & (::GT_MP_SCORE | ::GT_MP_TICKETS))
    {
      case ::GT_MP_SCORE:
        if (!needPlayersTbl)
          break

        local scoreFormat = "%s" + ::loc("multiplayer/score") + ::loc("ui/colon") + "%d"
        if (tbl.len() > playerTeamIdx)
        {
          setTeamInfoText(teamObj1, ::format(scoreFormat, teamTxt[0], tbl[playerTeamIdx].score))
          setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
        }
        if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
        {
          setTeamInfoText(teamObj2, ::format(scoreFormat, teamTxt[1], tbl[1-playerTeamIdx].score))
          setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        }
        break

      case ::GT_MP_TICKETS:
        local rounds = ::get_mp_rounds()
        local curRound = ::get_mp_current_round()

        if (needPlayersTbl)
        {
          local scoreLoc = (rounds > 0) ? ::loc("multiplayer/rounds") : ::loc("multiplayer/airfields")
          local scoreformat = "%s" + ::loc("multiplayer/tickets") + ::loc("ui/colon") + "%d" + ", " +
                                scoreLoc + ::loc("ui/colon") + "%d"

          if (tbl.len() > playerTeamIdx)
          {
            setTeamInfoText(teamObj1, ::format(scoreformat, teamTxt[0], tbl[playerTeamIdx].tickets, tbl[playerTeamIdx].score))
            setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
          }
          if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
          {
            setTeamInfoText(teamObj2, ::format(scoreformat, teamTxt[1], tbl[1 - playerTeamIdx].tickets, tbl[1 - playerTeamIdx].score))
            setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
          }
        }

        local statObj = scene.findObject("gc_mp_tickets_rounds")
        if (::checkObj(statObj))
        {
          local text = ""
          if (rounds > 0)
            text = ::loc("multiplayer/curRound", { round = curRound+1, total = rounds })
          statObj.setValue(text)
        }
        break
    }
  }

  function updateStats(customTbl = null, customTblTeams = null, customFriendlyTeam = null)
  {
    local playerTeam   = getLocalTeam()
    local friendlyTeam = customFriendlyTeam ?? ::get_player_army_for_hud()
    local tblObj1 = scene.findObject("table_kills_team1")
    local tblObj2 = scene.findObject("table_kills_team2")

    if (needPlayersTbl)
    {
      if (!isTeamplay || (gameType & ::GT_VERSUS))
      {
        if (!isTeamplay)
          playerTeam = Team.A

        setKillsTbl(tblObj1, playerTeam, playerTeam, friendlyTeam, showAircrafts, customTbl)
        if (!showLocalTeamOnly && playerTeam > 0)
          setKillsTbl(tblObj2, 3 - playerTeam, playerTeam, friendlyTeam, isShowEnemyAirs(), customTbl)
      }
      else
        setKillsTbl(tblObj2, -1, -1, -1, showAircrafts, customTbl)
    }

    if (playerTeam > 0)
      updateTeams(customTblTeams || ::get_mp_tbl_teams(), playerTeam, friendlyTeam)

    if (checkRaceDataOnStart && ::is_race_started())
    {
      local chObj = scene.findObject("gc_race_checkpoints")
      if (::checkObj(chObj))
      {
        local totalCheckpointsAmount = ::get_race_checkpioints_count()
        local text = ""
        if (totalCheckpointsAmount > 0)
          text = ::getCompoundedText(::loc("multiplayer/totalCheckpoints") + ::loc("ui/colon"), totalCheckpointsAmount, "activeTextColor")
        chObj.setValue(text)
        checkRaceDataOnStart = false
      }

      numberOfWinningPlaces = ::get_race_winners_count()
    }

    ::update_team_css_label(scene.findObject("num_teams"), playerTeam)
  }

  function updateTables(dt)
  {
    updateCooldown -= dt
    if (updateCooldown <= 0)
    {
      updateStats()
      updateCooldown = 3
    }

    if (isStatScreen || !needPlayersTbl)
      return

    if (isRespawn)
    {
      local selectedObj = getSelectedTable()
      if (!isModeStat)
      {
        local objTbl1 = scene.findObject("table_kills_team1")
        local curRow = objTbl1.getValue()
        if (curRow < 0 || curRow >= objTbl1.childrenCount())
          objTbl1.setValue(0)
      }
      else
        if (selectedObj == null)
        {
          scene.findObject("table_kills_team1").setValue(0)
          updateListsButtons()
        }
    }
    else
    {
      scene.findObject("table_kills_team1").setValue(-1)
      scene.findObject("table_kills_team2").setValue(-1)
    }
  }

  function createHeaderRow(tableObj, hdr, markupData, teamNum)
  {
    if (!markupData
        || typeof markupData != "table"
        || !("columns" in markupData)
        || !markupData.columns.len()
        || !::checkObj(tableObj))
      return ""

    local tblData = clone hdr

    if (::getTblValue("invert", markupData, false))
      tblData.reverse()

    local view = {cells = []}
    foreach(name in tblData)
    {
      local value = markupData.columns?[name]
      if (!value || typeof value != "table")
        continue

      view.cells.append({
        id = ::getTblValue("id", value, name)
        fontIcon = ::getTblValue("fontIcon", value, null)
        tooltip = ::getTblValue("tooltip", value, null)
        width = ::getTblValue("width", value, "")
      })
    }

    local tdData = ::handyman.renderCached(("gui/statistics/statTableHeaderCell"), view)
    local trId = "team-header" + teamNum
    local trSize = ::getTblValue("tr_size", markupData, "0,0")
    local trData = ::format("tr{id:t='%s'; size:t='%s'; %s}", trId, trSize, tdData)
    return trData
  }

  function goBack(obj) {}

  function onUserCard(obj)
  {
    local player = getSelectedPlayer();
    if (!player || player.isBot || !isOnline)
      return;

    ::gui_modal_userCard({ name = player.name /*, id = player.id*/ }); //search by nick no work, but session can be not exist at that moment
  }

  function onUserRClick(obj)
  {
    onStatsTblSelect(obj)
    ::session_player_rmenu(this, getSelectedPlayer(), getChatLog())
  }

  function onUserOptions(obj)
  {
    local selectedTableObj = getSelectedTable()
    if (!::check_obj(selectedTableObj))
      return

    onStatsTblSelect(selectedTableObj)
    local selectedPlayer = getSelectedPlayer()
    local orientation = selectedTableObj.id == "table_kills_team1"? RCLICK_MENU_ORIENT.RIGHT : RCLICK_MENU_ORIENT.LEFT
    ::session_player_rmenu(this, selectedPlayer, getChatLog(), getSelectedRowPos(selectedTableObj, orientation), orientation)
  }

  function getSelectedRowPos(selectedTableObj, orientation)
  {
    local rowNum = selectedTableObj.getValue()
    if (rowNum >= selectedTableObj.childrenCount())
      return null

    local rowObj = selectedTableObj.getChild(rowNum)
    local rowSize = rowObj.getSize()
    local rowPos = rowObj.getPosRC()

    local posX = rowPos[0]
    if (orientation == RCLICK_MENU_ORIENT.RIGHT)
      posX += rowSize[0]

    return [posX, rowPos[1] + rowSize[1]]
  }

  function getPlayerInfo(name)
  {
    if (name && name != "")
      foreach (tbl in [tblSave1, tblSave2])
        if (tbl)
          foreach(player in tbl)
            if (player.name == name)
              return player
    return null
  }

  function refreshPlayerInfo()
  {
    setPlayerInfo()

    local player = getSelectedPlayer()
    showSceneBtn("btn_user_options", isOnline && player && !player.isBot && !isSpectate && ::show_console_buttons)
    ::SquadIcon.updateListLabelsSquad()
  }

  function setPlayerInfo()
  {
    local playerInfo = getSelectedPlayer()
    local teamObj = scene.findObject("player_team")
    if (isTeam && ::checkObj(teamObj))
    {
      local teamTxt = ""
      local team = playerInfo? playerInfo.team : Team.Any
      if (team == Team.A)
        teamTxt = ::loc("multiplayer/teamA")
      else if (team == Team.B)
        teamTxt = ::loc("multiplayer/teamB")
      else
        teamTxt = ::loc("multiplayer/teamRandom")
      teamObj.setValue(::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt)
    }

    ::fill_gamer_card({
                      name = playerInfo? playerInfo.name : ""
                      clanTag = playerInfo? playerInfo.clanTag : ""
                      icon = (!playerInfo || playerInfo.isBot)? "cardicon_bot" : avatars.getIconById(playerInfo.pilotId)
                      country = playerInfo? playerInfo.country : ""
                    },
                    "player_", scene)
  }

  function onComplain(obj)
  {
    local pInfo = getSelectedPlayer()
    if (!pInfo || pInfo.isBot || pInfo.isLocal)
      return

    ::gui_modal_complain(pInfo)
  }

  function updateListsButtons()
  {
    refreshPlayerInfo()
  }

  function onStatTblFocus(obj)
  {
    if (::show_console_buttons && !obj.isHovered())
      obj.setValue(-1)
  }

  function getSelectedPlayer()
  {
    local value = scene.findObject("table_kills_team1")?.getValue() ?? -1
    if (value >= 0)
      return tblSave1?[value]
    value = scene.findObject("table_kills_team2")?.getValue() ?? -1
    return tblSave2?[value]
  }

  function getSelectedTable()
  {
    local objTbl1 = scene.findObject("table_kills_team1")
    if (objTbl1.getValue() >= 0)
      return objTbl1
    local objTbl2 = scene.findObject("table_kills_team2")
    if (objTbl2.getValue() >= 0)
      return objTbl2
    return null
  }

  function onStatsTblSelect(obj)
  {
    if (!needPlayersTbl)
      return
    if (obj.getValue() >= 0) {
      local table_name = obj.id == "table_kills_team2" ? "table_kills_team1" : "table_kills_team2"
      local tblObj = scene.findObject(table_name)
      tblObj.setValue(-1)
    }
    updateListsButtons()
  }

  function selectLocalPlayer()
  {
    if (!needPlayersTbl)
      return false
    foreach (tblIdx, tbl in [ tblSave1, tblSave2 ])
      if (tbl)
        foreach(playerIdx, player in tbl)
          if (::getTblValue("isLocal", player, false))
            return selectPlayerByIndexes(tblIdx, playerIdx)
    return false
  }

  function selectPlayerByIndexes(tblIdx, playerIdx)
  {
    if (!needPlayersTbl)
      return false
    local selectedObj = getSelectedTable()
    if (selectedObj)
      selectedObj.setValue(-1)

    local tblObj = scene.findObject("table_kills_team" + (tblIdx + 1))
    if (!::check_obj(tblObj) || tblObj.childrenCount() <= playerIdx)
      return false

    tblObj.setValue(playerIdx)
    updateListsButtons()
    return true
  }

  function includeMissionInfoBlocksToGamercard(fill = true)
  {
    if (!::checkObj(scene))
      return

    local blockSample = "textareaNoTab{id:t='%s'; %s overlayTextColor:t='premiumNotEarned'; textShade:t='yes'; text:t='';}"
    local leftBlockObj = scene.findObject("mission_texts_block_left")
    if (::checkObj(leftBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_time_end", "gc_score_limit", "gc_time_to_kick"])
          data += ::format(blockSample, id, "")
      guiScene.replaceContentFromText(leftBlockObj, data, data.len(), this)
    }

    local rightBlockObj = scene.findObject("mission_texts_block_right")
    if (::checkObj(rightBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_spawn_score", "gc_wp_respawn_balance", "gc_race_checkpoints", "gc_mp_tickets_rounds"])
          data += ::format(blockSample, id, "pos:t='pw-w, 0'; position:t='relative';")
      guiScene.replaceContentFromText(rightBlockObj, data, data.len(), this)
    }
  }

  /**
   * Sets country flag visibility for both
   * teams based on players' countries and units.
   */
  function updateCountryFlags()
  {
    local playerTeam = getLocalTeam()
    if (!needPlayersTbl || playerTeam <= 0)
      return
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")
    local countries
    local teamIco

    if (::checkObj(teamObj1))
    {
      local teamOverrideCountryIcon = getOverrideCountryIconByTeam(playerTeam)
      countries = isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? getCountriesByTeam(playerTeam)
        : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "allies"
          : playerTeam == Team.A ? "allies" : "axis"
      setTeamInfoTeamIco(teamObj1, teamIco)
      setTeamInfoCountries(teamObj1, countries)
      updateOverrideCountry(teamObj1, teamOverrideCountryIcon)
    }
    if (!showLocalTeamOnly && ::checkObj(teamObj2))
    {
      local opponentTeam = playerTeam == Team.A ? Team.B : Team.A
      local teamOverrideCountryIcon = getOverrideCountryIconByTeam(opponentTeam)
      countries = isTeamsWithCountryFlags && !teamOverrideCountryIcon
        ? getCountriesByTeam(opponentTeam)
        : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "axis"
          : playerTeam == Team.A ? "axis" : "allies"
      setTeamInfoTeamIco(teamObj2, teamIco)
      setTeamInfoCountries(teamObj2, countries)
      updateOverrideCountry(teamObj2, teamOverrideCountryIcon)
    }
  }

  /**
   * Returns country names list based of players' settings.
   */
  function getCountriesByTeam(team)
  {
    local countries = []
    local players = getMplayersList(team)
    foreach (player in players)
    {
      local country = ::getTblValue("country", player, null)

      // If player/bot has random country we'll
      // try to retrieve country from selected unit.
      // Before spawn bots has wrong unit names.
      if (country == "country_0" && (!player.isDead || player.deaths > 0))
      {
        local unitName = ::getTblValue("aircraftName", player, null)
        local unit = ::getAircraftByName(unitName)
        if (unit != null)
          country = ::getUnitCountry(unit)
      }
      ::u.appendOnce(country, countries, true)
    }
    return countries
  }

  function getEndTimeObj()
  {
    return scene.findObject("gc_time_end")
  }

  function getScoreLimitObj()
  {
    return scene.findObject("gc_score_limit")
  }

  function getTimeToKickObj()
  {
    return scene.findObject("gc_time_to_kick")
  }

  function setGameEndStat(timeLeft)
  {
    local gameEndsObj = getEndTimeObj()
    local scoreLimitTextObj = getScoreLimitObj()

    if (!(gameType & ::GT_VERSUS))
    {
      foreach(obj in [gameEndsObj, scoreLimitTextObj])
        if (::checkObj(obj))
          obj.setValue("")
      return
    }

    if (::get_mp_rounds())
    {
      local rl = ::get_mp_zone_countdown()
      if (rl > 0)
        timeLeft = rl
    }

    if (timeLeft < 0 || (gameType & ::GT_RACE))
    {
      if (!::checkObj(gameEndsObj))
        return

      local val = gameEndsObj.getValue()
      if (typeof val == "string" && val.len() > 0)
        gameEndsObj.setValue("")
    }
    else
    {
      if (::checkObj(gameEndsObj))
        gameEndsObj.setValue(::getCompoundedText(::loc("multiplayer/timeLeft") + ::loc("ui/colon"),
                                                 time.secondsToString(timeLeft, false),
                                                 "activeTextColor"))

      local mp_ffa_score_limit = ::get_mp_ffa_score_limit()
      if (!isTeamplay && mp_ffa_score_limit && ::checkObj(scoreLimitTextObj))
        scoreLimitTextObj.setValue(::getCompoundedText(::loc("options/scoreLimit") + ::loc("ui/colon"),
                                   mp_ffa_score_limit,
                                   "activeTextColor"))
    }
  }

  function updateNumMaxPlayers(shouldHideRows = false)
  {
     local tblObj1 = scene.findObject("table_kills_team1")
     if (!::checkObj(tblObj1))
       return

     local curValue = numMaxPlayers
     numMaxPlayers = ::ceil(tblObj1.getParent().getSize()[1]/(::to_pixels("1@rows16height") || 1)).tointeger()
     if (!shouldHideRows || curValue <= numMaxPlayers)
       return

     hideTableRows(tblObj1, numMaxPlayers, curValue)
     tblObj1 = scene.findObject("table_kills_team2")
     if (!::checkObj(tblObj1))
       return
     hideTableRows(tblObj1, numMaxPlayers, curValue)
  }

  function hideTableRows(tblObj, minRow, maxRow)
  {
    local count = tblObj.childrenCount()
    for (local i = minRow; i < maxRow; i++)
    {
      if (count <= i)
        return

      tblObj.getChild(i).show(false)
    }

  }

  function getChatLog()
  {
    return mpChatModel.getLogForBanhammer()
  }

  getLocalTeam = @() ::get_local_team_for_mpstats()
  getMplayersList = @(team) ::get_mplayers_list(team, true)
  getOverrideCountryIconByTeam = @(team)
    ::g_mis_custom_state.getCurMissionRules().getOverrideCountryIconByTeam(team)
}

class ::gui_handlers.MPStatScreen extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "gui/mpStatistics.blk"
  sceneNavBlkName = "gui/navMpStat.blk"
  shouldBlurSceneBg = true
  keepLoaded = true

  wasTimeLeft = -1
  isFromGame = false
  isWideScreenStatTbl = true
  showAircrafts = true

  function initScreen()
  {
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)

    //!!init debriefing
    isModeStat = true
    isRespawn = true
    isSpectate = false
    isTeam  = true

    local tblObj1 = scene.findObject("table_kills_team1")
    if (tblObj1.childrenCount() == 0)
      initStats()

    if (gameType & ::GT_COOPERATIVE)
    {
      scene.findObject("team1-root").show(false)
      isTeam = false
    }

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    tblObj1.setValue(0)
    scene.findObject("table_kills_team2").setValue(-1)

    refreshPlayerInfo()

    showSceneBtn("btn_back", true)

    wasTimeLeft = -1
    scene.findObject("stat_update").setUserData(this)
    isStatScreen = true
    forceUpdate()
    updateListsButtons()

    updateStats()

    showSceneBtn("btn_activateorder", ::g_orders.showActivateOrderButton())
    local ordersButton = scene.findObject("btn_activateorder")
    if (::checkObj(ordersButton))
    {
      ordersButton.setUserData(this)
      ordersButton.inactiveColor = !::g_orders.orderCanBeActivated() ? "yes" : "no"
    }
  }

  function reinitScreen(params)
  {
    setParams(params)
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)
    forceUpdate()
    if (::is_replay_playing())
      selectLocalPlayer()
  }

  function forceUpdate()
  {
    updateCooldown = -1
    onUpdate(null, 0.0)
  }

  function onUpdate(obj, dt)
  {
    local timeLeft = ::get_multiplayer_time_left()
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
    updateTimeToKick(dt)
    updateTables(dt)
  }

  function goBack(obj)
  {
    ::in_flight_menu(false)
    if (isFromGame)
      ::close_ingame_gui()
    else
      ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onApply()
  {
    goBack(null)
  }

  function onHideHUD(obj) {}
}

::SquadIcon <- {
  listLabelsSquad = {}
  nextLabel = { team1 = 1, team2 = 1}
  topSquads = {}
  playersInfo = {}
}

SquadIcon.initListLabelsSquad <- function initListLabelsSquad()
{
  listLabelsSquad.clear()
  nextLabel.team1 = 1
  nextLabel.team2 = 1
  topSquads = {}
  playersInfo = {}
  updatePlayersInfo()
}

SquadIcon.getPlayersInfo <- function getPlayersInfo()
{
  return playersInfo
}

SquadIcon.updatePlayersInfo <- function updatePlayersInfo()
{
  local sessionPlayersInfo = ::SessionLobby.getPlayersInfo()
  if (sessionPlayersInfo.len() > 0 && !::u.isEqual(playersInfo, sessionPlayersInfo))
    playersInfo = clone sessionPlayersInfo
}

SquadIcon.updateListLabelsSquad <- function updateListLabelsSquad()
{
  foreach(label in listLabelsSquad)
    label.count = 0;
  local team = ""
  foreach(uid, member in getPlayersInfo())
  {
    team = "team"+member.team
    if (!(team in nextLabel))
      continue

    local squadId = member.squad
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadId in listLabelsSquad)
    {
      if (listLabelsSquad[squadId].count < 2)
      {
        listLabelsSquad[squadId].count++
        if (listLabelsSquad[squadId].count > 1 && listLabelsSquad[squadId].label == "")
        {
          listLabelsSquad[squadId].label = nextLabel[team].tostring()
          nextLabel[team]++
        }
      }
    }
    else
      listLabelsSquad[squadId] <- {
        squadId = squadId
        count = 1
        label = ""
        autoSquad = ::getTblValue("auto_squad", member, false)
        teamId = member.team
      }
  }
}

SquadIcon.getSquadInfo <- function getSquadInfo(idSquad)
{
  if (idSquad == INVALID_SQUAD_ID)
    return null
  local squad = (idSquad in listLabelsSquad) ? listLabelsSquad[idSquad] : null
  if (squad == null)
    return null
  else if (squad.count < 2)
    return null
  return squad
}

SquadIcon.getSquadInfoByMemberName <- function getSquadInfoByMemberName(name)
{
  if (name == "")
    return null

  foreach(uid, member in getPlayersInfo())
    if (member.name == name)
      return getSquadInfo(member.squad)

  return null
}

SquadIcon.updateTopSquadScore <- function updateTopSquadScore(mplayers)
{
  if (!isShowSquad())
    return
  local teamId = mplayers.len() ? ::getTblValue("team", mplayers[0], null) : null
  if (teamId == null)
    return

  local topSquadId = null

  local topSquadScore = 0
  local squads = {}
  foreach (player in mplayers)
  {
    local squadScore = ::getTblValue("squadScore", player, 0)
    if (!squadScore || squadScore < topSquadScore)
      continue
    local name = ::getTblValue("name", player, "")
    local squadId = ::getTblValue("squadId", getSquadInfoByMemberName(name), INVALID_SQUAD_ID)
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadScore > topSquadScore)
    {
      topSquadScore = squadScore
      squads.clear()
    }
    local score = ::getTblValue("score", player, 0)
    if (!(squadId in squads))
      squads[squadId] <- { playerScore = 0, members = 0 }
    squads[squadId].playerScore += score
    squads[squadId].members++
  }

  local topAvgPlayerScore = 0.0
  foreach (squadId, data in squads)
  {
    local avg = data.playerScore * 1.0 / data.members
    if (topSquadId == null || avg > topAvgPlayerScore)
    {
      topSquadId = squadId
      topAvgPlayerScore = avg
    }
  }

  topSquads[teamId] <- topSquadId
}

SquadIcon.getTopSquadId <- function getTopSquadId(teamId)
{
  return ::getTblValue(teamId, topSquads)
}

SquadIcon.isShowSquad <- function isShowSquad()
{
  if (::SessionLobby.getGameMode() == ::GM_SKIRMISH)
    return false

  return true
}
