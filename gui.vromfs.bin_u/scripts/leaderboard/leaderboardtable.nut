from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRow
import "%scripts/time.nut" as time
import "%sqstd/math.nut" as stdMath

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getContactByName } = require("%scripts/contacts/contactsManager.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")

gui_handlers.LeaderboardTable <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/leaderboard/leaderboardTable.tpl"

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

  static function create(config) {
    return handlersManager.loadHandler(gui_handlers.LeaderboardTable, config)
  }

  function getSceneTplView() {
    return {}
  }

  function updateParams(curModel, curPresets, curCategory, curParams, isCurClanLb = false) {
    this.lbModel = curModel
    this.lbPresets = curPresets
    this.lbCategory = curCategory
    this.lbParams = curParams
    this.isClanLb = isCurClanLb
  }

  function showLoadingAnimation() {
    showObjById("wait_animation", true, this.scene)
    showObjById("no_leaderboads_text", false, this.scene)
    showObjById("lb_table", false, this.scene)
  }

  function fillTable(lbRows, selfRow, selfPos, hasHeader, hasTable) {
    local data = ""
    if (hasHeader) {
      let headerRow = [
        { text = "#multiplayer/place", width = "0.1@sf" },
        { text = this.isClanLb ? "#clan/clan_name" : "#multiplayer/name",
          tdalign = "center", width = this.isClanLb ? 0 : "0.12@sf" }
      ]
      foreach (category in this.lbPresets) {
        if (!this.lbModel.checkLbRowVisibility(category, this.lbParams))
          continue

        let block = {
          id = category.id
          image = category.headerImage
          tooltip = category.headerTooltip
          needText = false
          active = this.lbCategory == category
          callback = "onCategory"
        }
        headerRow.append(block)
      }
      data = "".concat(data, buildTableRow("row_header", headerRow, null, "isShortLeaderBoardHeader:t='yes'"))
    }

    this.isLastPage = false
    if (hasTable) {
      local rowIdx = 0
      foreach (row in lbRows)
        data = "".concat(data, this.getTableRowMarkup(row, rowIdx++, selfPos))

      if (rowIdx < this.rowsInPage) {
        for (local i = rowIdx; i < this.rowsInPage; i++)
          data = "".concat(data, buildTableRow($"row_{i}", [], i % 2 == 0, "inactive:t='yes';"))
        this.isLastPage = true
      }

      data = "".concat(data, this.generateSelfRow(selfRow))
    }

    let lbTable = this.scene.findObject("lb_table")
    this.guiScene.replaceContentFromText(lbTable, data, data.len(), this)

    if (hasTable)
      this.onRowSelect(lbTable)

    showObjById("wait_animation", !hasHeader && !hasTable, this.scene)
    showObjById("no_leaderboads_text", hasHeader && !hasTable, this.scene)
    showObjById("lb_table", hasHeader && hasTable, this.scene)
  }

  function getTableRowMarkup(row, rowIdx, selfPos) {
    let needAddClanTag = row?.needAddClanTag ?? false
    let clanTag = row?.clanTag ?? ""
    let rowName = row?.name ?? ""
    let playerName = getCustomNick(getContactByName(rowName))
      ?? (this.isClanLb ? rowName : getPlayerName(rowName))
    let rowData = [
      {
        text = row.pos >= 0 ? (row.pos + 1).tostring() : loc("leaderboards/notAvailable")
      }
      {
        id = "name"
        tdalign = "left"
        text = needAddClanTag
          ? getPlayerFullName(playerName, clanTag)
          : playerName
      }
    ]
    let isMainPlayer = selfPos == row.pos && row.pos >= 0
    let customSelfStats = isMainPlayer ? this.lbParams?.customSelfStats : null
    foreach (category in this.lbPresets) {
      if (!this.lbModel.checkLbRowVisibility(category, this.lbParams))
        continue

      let itemCell = this.getItemCell(category, row)
      if (customSelfStats != null) {
        let customTooltip = this.getCustomSelfStatsTooltip(category, customSelfStats)
        itemCell.tooltip <- itemCell?.tooltip == null ? customTooltip
          : $"{itemCell.tooltip}\n\n{customTooltip}"
        itemCell.text = $"{itemCell.text} ┋"
      }
      rowData.append(itemCell)
    }
    let clanId = needAddClanTag && clanTag == "" ? (row?.clanId ?? "") : ""
    let rowParamsText = $"clanId:t='{clanId}';{isMainPlayer ? "mainPlayer:t='yes';" : ""}"
    let data = buildTableRow($"row_{rowIdx}", rowData, rowIdx % 2 == 0, rowParamsText)

    return data
  }

  function getCustomSelfStatsTooltip(category, customSelfStats) {
    if (category.id == "EVENT_SCORE_RATING" || category.id == "EVENT_SCORE_RATING_X10000") {
      let bestStats = (customSelfStats?["$sessions"] ?? [])
        .filter(@(s) (s?.stats.score_rating ?? 0) > 0)
        .sort(@(a, b) b.stats.score_rating <=> a.stats.score_rating)

      if (bestStats.len() == 0)
        return ""

      let bestStatsStrArr = []
      bestStats.each(@(s) bestStatsStrArr.append(" ".concat(
        $"{stdMath.round_by_value(s.stats.score_rating, 0.1)}",
        "=",
        $"({s.stats?.ext1 ?? 0} + 0.2 x {s.stats?.ext2 ?? 0})",
        "/",
        $"{time.buidPartialTimeStr((s.stats?.missiontime ?? 0) * 0.001)}"
      )))

      return $"{loc("results_best")}{loc("ui/colon")}\n{"\n".join(bestStatsStrArr)}"
    }

    let { field } = category
    local bestStats = (customSelfStats?["$sessions"] ?? [])
      .map(@(s) s?.stats[field] ?? 0).filter(@(stat) stat > 0).sort(@(a, b) b <=> a)

    if (bestStats.len() == 0)
      return ""

    bestStats = bestStats.map(@(value) category.lbDataType.getShortTextByValue(value))
    return $"{loc("results_best")}{loc("ui/colon")}\n{"\n".join(bestStats)}"
  }

  function getItemCell(curLbCategory, row) {
    let value = curLbCategory.field in row ? row[curLbCategory.field] : 0
    let res = curLbCategory.getItemCell(value, row)
    res.active <- this.lbCategory == curLbCategory

    return res
  }

  function generateSelfRow(selfRow) {
    if (!selfRow || selfRow.len() <= 0)
      return ""

    let emptyRow = buildTableRow($"row_{this.rowsInPage}", ["..."], null,
      "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;'; ")

    return "".concat(emptyRow, this.getTableRowMarkup(selfRow[0], this.rowsInPage + 1, selfRow[0].pos))
  }

  function onRowSelect(obj) {
    if (showConsoleButtons.get())
      return
    if (!checkObj(obj))
      return

    let dataIdx = obj.getValue() - 1 
    this.onRowSelectCb?(dataIdx)
  }

  function onRowHover(obj) {
    if (!showConsoleButtons.get())
      return
    if (!checkObj(obj))
      return

    let isHover = obj.isHovered()
    let dataIdx = to_integer_safe(cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == this.lastHoveredDataIdx))
     return

    this.lastHoveredDataIdx = isHover ? dataIdx : -1
    this.onRowHoverCb?(this.lastHoveredDataIdx)
  }

  function onRowDblClick() {
    if (this.onRowDblClickCb)
      this.onRowDblClickCb()
  }

  function onRowRClick() {
    if (this.onRowRClickCb)
      this.onRowRClickCb()
  }

  function onCategory(obj) {
    if (this.onCategoryCb)
      this.onCategoryCb(obj)
  }
}
