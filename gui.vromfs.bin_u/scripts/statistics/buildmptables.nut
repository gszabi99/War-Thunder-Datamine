from "string" import format
from "guiMission" import get_mp_session_info
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/playerStateConsts.nut" import *
from "%scripts/utils_sa.nut" import locOrStrip
from "%scripts/mplayerParamType.nut" import g_mplayer_param_type
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/ranks.nut" import getRankByExp
from "%scripts/contacts/contactsInfo.nut" import getPlayerFullName, colorizeWhitePsnIcon
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import isMemberInMySquadById
from "%scripts/statistics/mpStatisticsInfo.nut" import getWeaponTypeIcoByWeapon
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%sqStdLibs/helpers/u.nut" import isEmpty

let colsWithParamType = { aiTotalKills = true, assists = true, score = true, damageZone = true,
  raceFinishTime = true, raceLastCheckpoint = true, raceLastCheckpointTime = true, damageZoneNuke = true,
  raceBestLapTime = true, missionAliveTime = true, kills = true, deaths = true, navalKills = true
}

let colsWithCustomTooltip = { name = true, aircraft = true, unitIcon = true, score = true }
let colsWithWishlistContextMenu = hasFeature("Wishlist")
  ? { aircraft = true, unitIcon = true }
  : { }

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

function createExpSkillBonusIcon(tooltipFunction) {
  return "".concat("img{ id:t='exp_skill_bonus_icon' not-input-transparent:t='yes'; tooltip:t='$tooltipObj'; size:t='@tableIcoSize, @tableIcoSize';",
    "top:t='0.5ph-0.5h'; position:t='relative';background-image:t='';",
    "background-svg-size:t='@tableIcoSize, @tableIcoSize'; left:t='0'; margin:t='2@dp, 0'; tooltipObj{", $"on_tooltip_open:t='{tooltipFunction}';",
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

  let { hasCustomTooltip = false } = params

  let data = []
  for (local i = 0; i < numRows; i++) {
    let isRowEmpty = i >= numTblRows
    let trData = [format("even:t='%s'; ", (i % 2 == 0) ? "yes" : "no")]
    let trAdd = [isRowEmpty ? "inactive:t='yes'; " : ""]
    if (!isEmpty(trOnHover))
      trAdd.append($"rowIdx='{i}'; on_hover:t='{trOnHover}'; on_unhover:t='{trOnHover}';")

    for (local j = 0; j < hdr.len(); ++j) {
      local item = ""
      local tdData = ""
      let widthAdd = ((j == 0) || (j == (hdr.len() - 1))) ? "+@tablePad" : ""
      const textPadding = "style:t='padding:@tablePad,0;'; "
      let customTooltipId = hasCustomTooltip && hdr[j] in colsWithCustomTooltip
        ? $"{hdr[j]}_tooltip"
        : null

      if (!isRowEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] == "hasPassword") {
        let icon = item ? "#ui/gameuiskin#password.svg" : ""
        tdData = "".concat("size:t='ph", widthAdd, " ,ph';",
          "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';",
          "background-svg-size:t='@tableIcoSize,@tableIcoSize'; background-image:t='", isRowEmpty ? "" : icon, "'; }")
      }
      else if (hdr[j] == "team") {
        let teamText = "teamImg{ text { halign:t='center'}} "
        tdData = "".concat("size:t='ph", widthAdd, ",ph'; css-hier-invalidate:t='yes'; team:t=''; ", teamText)
      }
      else if (hdr[j] == "country" || hdr[j] == "teamCountry") {
        local country = ""
        if (hdr[j] == "country")
          country = item
        else if (!isRowEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        local icon = ""
        if (!isRowEmpty && country != "")
          icon = getCountryIcon(country)
        tdData = format("".concat("size:t='ph%s,ph';",
          "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize, 0.66@tableIcoSize';",
          "background-image:t='%s'; background-svg-size:t='@tableIcoSize, 0.66@tableIcoSize'; background-repeat:t='aspect-ratio';",
          "}"), widthAdd, icon)
      }
      else if (hdr[j] == "status") {
        tdData = format("size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico' } ", widthAdd)
      }
      else if (hdr[j] == "name") {
        local nameText = item
        if (!isRowEmpty && !isHeader && !table[i].isBot)
          nameText = getPlayerFullName(getPlayerName(nameText), table[i].clanTag)

        nameText = stripTags(colorizeWhitePsnIcon(nameText))
        let nameWidth = markup?[hdr[j]]?.width ?? "0.5pw-0.035sh"
        let nameAlign = isRowInvert ? "text-align:t='right' " : ""
        tdData = "".concat($"width:t='{nameWidth}'; {textPadding}",
          "textareaNoTab {",
            $"id:t='name-text'; {nameAlign} text:t = '{nameText}';",
            "pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';",
          "}")
        if (!isRowEmpty) {
          
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
        if (!isRowEmpty && ("exp" in table[i]) && ("prestige" in table[i])) {
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
          tdProp.append(format("width:t='%s'", (markup[hdr[j]]?.width ?? "")))

        tdData = format("%s activeText { text:t = '%i'; halign:t='center'} ", "".join(tdProp), i + 1)
      }
      else if (hdr[j] == "place") {
        let width = $"width:t='{markup[hdr[j]]?.width ?? 1}'; "
        tdData = format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (hdr[j] in colsWithParamType) {
        let txt = isRowEmpty ? "" : g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData = format("activeText { text:t='%s' halign:t='center' } ", txt)
        let width = ((markup?[hdr[j]] ?? {})?.width ?? "")
        if (width != "")
          tdData = "".concat(tdData, format("width:t='%s'; ", width))
      }
      else if (hdr[j] == "numPlayers") {
        let curWidth = ((hdr[j] in markup) && ("width" in markup[hdr[j]])) ? markup[hdr[j]].width : "0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isRowEmpty && "numPlayersTotal" in table[i]) {
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
              colorTeam, $"icon_{hdr[j]}", markup[hdr[j]].image, isRowEmpty ? "hide" : "show"
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
      if (hdr[j] in colsWithWishlistContextMenu)
        trData.append("cursor:t='normal'; isNavInContainerBtn:t='no'; contextMenu:t='no'; ")
      if (j == 0)
        trData.append("padding-left:t='@tablePad'; ")
      if (j > 0)
        trData.append("cellType:t = 'border'; ")
      if (j == (hdr.len() - 1))
        trData.append("padding-right:t='@tablePad'; ")
      trData.append(tdData)
      if (customTooltipId)
        trData.append(createCellCustomTooltip(customTooltipId))
      trData.append(" }")
    }

    data.append("".concat("tr {size:t = '", trSize, "'; ", "".join(trAdd), "".join(trData),
      " text-valign:t='center'; css-hier-invalidate:t='all'; }"))
  }

  return "\n".join(data)
}


return freeze({
  buildMpTable
})