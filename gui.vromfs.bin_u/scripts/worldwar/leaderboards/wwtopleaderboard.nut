local wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")


local function initTop(handler, obj, modeName, day = null, amount = 3, field = "rating")
{
  wwLeaderboardData.requestWwLeaderboardData(modeName,
    {
      gameMode = modeName
      table    = day && day > 0 ? "day" + day : "season"
      start = 0
      count = amount
      category = field
    },
    function(lbData) {
      displayTop(handler, obj, lbData, { modeName = modeName, day = day })
    }.bindenv(this))
}

local function generateTableRow(row, rowIdx, lbCategory)
{
  local rowName = "row_" + rowIdx
  local rowData = [
    {
      text = (row.pos + 1).tostring()
      width = "0.01@sf"
      cellType = "top_numeration"
    },
    {
      id = "name"
      width = "0.5pw"
      tdAlign = "left"
      text = row.name
      active = false
    }
  ]

  if (lbCategory)
  {
    local td = lbCategory.getItemCell(::getTblValue(lbCategory.field, row, -1))
    td.tdAlign <- "right"
    rowData.append(td)
  }

  return ::buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
}

local function displayTop(handler, obj, lbData, lbInfo)
{
  if (!handler.isValid() || !::check_obj(obj))
    return

  if (!lbData || lbData?.error)
    return

  local lbRows = ::u.filter(wwLeaderboardData.convertWwLeaderboardData(lbData).rows,
    @(lb) lb.pos >= 0)
  local hasLbRows = lbRows.len() > 0
  obj.show(hasLbRows)

  if (!hasLbRows)
    return

  local lbCategory = ::g_lb_category.WW_EVENTS_PERSONAL_ELO
  local locId = "worldwar/top/" + lbInfo.modeName + "/" +
    (lbInfo.day && lbInfo.day > 0 ? "daily" : "season")
  local rowIdx = 0
  local topView = {
    titleText = ::loc(locId)
    lbMode = lbInfo.modeName
    isDayLb = lbInfo.day && lbInfo.day > 0 ? "yes" : "no"
    rows = ::u.map(lbRows, @(row) { row = generateTableRow(row, rowIdx++, lbCategory) })
  }
  local topBlk = ::handyman.renderCached("gui/worldWar/wwTopLeaderboard", topView)
  ::get_cur_gui_scene().replaceContentFromText(obj, topBlk, topBlk.len(), handler)

  handler.showTopListBlock(true)
}

return {
  initTop = initTop
  displayTop = displayTop
}
