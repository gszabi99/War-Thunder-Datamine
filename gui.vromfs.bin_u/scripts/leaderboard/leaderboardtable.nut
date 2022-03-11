local platformModule = require("scripts/clientState/platform.nut")

class ::gui_handlers.LeaderboardTable extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/leaderboard/leaderboardTable"

  isLastPage = false
  lbParams   = null
  lbModel    = null
  lbPresets  = null
  lbCategory = null
  isClanLb   = false
  rowsInPage = 0

  lastHoveredDataIdx = -1

  onCategoryCb = null
  onRowSelectCb = null
  onRowHoverCb = null
  onRowDblClickCb = null
  onRowRClickCb = null

  static function create(config)
  {
    return ::handlersManager.loadHandler(::gui_handlers.LeaderboardTable, config)
  }

  function getSceneTplView()
  {
    return {}
  }

  function updateParams(curModel, curPresets, curCategory, curParams, isCurClanLb = false)
  {
    lbModel = curModel
    lbPresets = curPresets
    lbCategory = curCategory
    lbParams = curParams
    isClanLb = isCurClanLb
  }

  function showLoadingAnimation()
  {
    showSceneBtn("wait_animation", true)
    showSceneBtn("no_leaderboads_text", false)
    showSceneBtn("lb_table", false)
  }

  function fillTable(lbRows, selfRow, selfPos, hasHeader, hasTable)
  {
    local data = ""
    if (hasHeader)
    {
      local headerRow = [
        { text = "#multiplayer/place", width = "0.1@sf" },
        { text = isClanLb ? "#clan/clan_name" : "#multiplayer/name",
          tdalign = "center", width = isClanLb ? 0 : "0.12@sf" }
      ]
      foreach(category in lbPresets)
      {
        if (!lbModel.checkLbRowVisibility(category, lbParams))
          continue

        local block = {
          id = category.id
          image = category.headerImage
          tooltip = category.headerTooltip
          needText = false
          active = lbCategory == category
          callback = "onCategory"
        }
        headerRow.append(block)
      }
      data += buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'")
    }

    isLastPage = false
    if (hasTable)
    {
      local rowIdx = 0
      foreach(row in lbRows)
        data += getTableRowMarkup(row, rowIdx++, selfPos)

      if (rowIdx < rowsInPage)
      {
        for(local i = rowIdx; i < rowsInPage; i++)
          data += buildTableRow("row_" + i, [], i % 2 == 0, "inactive:t='yes';")
        isLastPage = true
      }

      data += generateSelfRow(selfRow)
    }

    local lbTable = scene.findObject("lb_table")
    guiScene.replaceContentFromText(lbTable, data, data.len(), this)

    if (hasTable)
      onRowSelect(lbTable)

    showSceneBtn("wait_animation", !hasHeader && !hasTable)
    showSceneBtn("no_leaderboads_text", hasHeader && !hasTable)
    showSceneBtn("lb_table", hasHeader && hasTable)
  }

  function getTableRowMarkup(row, rowIdx, selfPos)
  {
    local needAddClanTag = row?.needAddClanTag ?? false
    local clanTag = row?.clanTag ?? ""
    local playerName = platformModule.getPlayerName(row?.name ?? "")
    local rowData = [
      {
        text = row.pos >= 0 ? (row.pos + 1).tostring() : ::loc("leaderboards/notAvailable")
      }
      {
        id = "name"
        tdalign = "left"
        text = needAddClanTag
          ? ::g_contacts.getPlayerFullName(playerName, clanTag)
          : playerName
      }
    ]
    foreach(category in lbPresets)
    {
      if (!lbModel.checkLbRowVisibility(category, lbParams))
        continue

      rowData.append(getItemCell(category, row))
    }
    local clanId = needAddClanTag && clanTag == "" ? (row?.clanId ?? "") : ""
    local highlightRow = selfPos == row.pos && row.pos >= 0
    local rowParamsText = $"clanId:t='{clanId}';{highlightRow ? "mainPlayer:t='yes';" : ""}"
    local data = buildTableRow("row_" + rowIdx, rowData, rowIdx % 2 == 0, rowParamsText)

    return data
  }

  function getItemCell(curLbCategory, row)
  {
    local value = curLbCategory.field in row ? row[curLbCategory.field] : 0
    local res = curLbCategory.getItemCell(value, row)
    res.active <- lbCategory == curLbCategory

    return res
  }

  function generateSelfRow(selfRow)
  {
    if (!selfRow || selfRow.len() <= 0)
      return ""

    local emptyRow = buildTableRow("row_"+rowsInPage, ["..."], null,
      "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;'; ")

    return emptyRow + generateRowTableData(selfRow[0], rowsInPage + 1, selfRow)
  }

  function generateRowTableData(row, rowIdx, selfRow)
  {
    local rowName = "row_" + rowIdx
    local needAddClanTag = row?.needAddClanTag ?? false
    local clanTag = row?.clanTag ?? ""
    local playerName = platformModule.getPlayerName(row?.name ?? "")
    local rowData = [
      {
        text = row.pos >= 0 ? (row.pos + 1).tostring() : ::loc("leaderboards/notAvailable")
      },
      {
        id = "name"
        tdalign = "left"
        text = needAddClanTag
          ? ::g_contacts.getPlayerFullName(playerName, clanTag)
          : playerName
      }
    ]
    foreach(category in lbPresets)
    {
      if (!lbModel.checkLbRowVisibility(category, lbParams))
        continue

      rowData.append(getItemCell(category, row))
    }

    local clanId = needAddClanTag && clanTag == "" ? (row?.clanId ?? "") : ""
    local highlightRow = selfRow == row.pos && row.pos >= 0
    local data = buildTableRow(rowName, rowData, rowIdx % 2 == 0,
      $"clanId:t='{clanId}';{highlightRow ? "mainPlayer:t='yes';" : ""}")

    return data
  }

  function onRowSelect(obj)
  {
    if (::show_console_buttons)
      return
    if (!::check_obj(obj))
      return

    local dataIdx = obj.getValue() - 1 // skiping header row
    onRowSelectCb?(dataIdx)
  }

  function onRowHover(obj)
  {
    if (!::show_console_buttons)
      return
    if (!::check_obj(obj))
      return

    local isHover = obj.isHovered()
    local dataIdx = ::to_integer_safe(::g_string.cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == lastHoveredDataIdx))
     return

    lastHoveredDataIdx = isHover ? dataIdx : -1
    onRowHoverCb?(lastHoveredDataIdx)
  }

  function onRowDblClick()
  {
    if (onRowDblClickCb)
      onRowDblClickCb()
  }

  function onRowRClick()
  {
    if (onRowRClickCb)
      onRowRClickCb()
  }

  function onCategory(obj)
  {
    if (onCategoryCb)
      onCategoryCb(obj)
  }
}
