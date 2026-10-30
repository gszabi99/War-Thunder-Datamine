import "%scripts/seen/bhvUnseen.nut" as bhvUnseen
import "%sqstd/math.nut" as stdMath
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/unlocks/favoriteUnlocks.nut" import isUnlockFav, toggleUnlockFav
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible
from "%scripts/unlocks/unlocksCache.nut" import getAllUnlocksWithBlkOrder
from "%scripts/tasker.nut" import addTask
from "%scripts/myStats.nut" import getTitles, getStats, clearStats
from "math" import ceil
from "%sqstd/string.nut" import utf8ToLower
from "%scripts/dagui_natives.nut" import select_current_title
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let ChooseTitle = class (BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/profile/chooseTitle.tpl"

  curTitle = ""
  ownTitles = null
  titlesList = null
  onCompleteFunc = null

  static function open(params) {
    if (!isInMenu.get() || !getStats())
      return

    handlersManager.loadHandler(get_gui_handler("ChooseTitle"), params)
  }

  function getSceneTplView() {
    this.ownTitles = getTitles()
    this.titlesList = getAllUnlocksWithBlkOrder()
      .filter(@(u) u?.type == "title" && isUnlockVisible(u))
      .map(@(u) u.id)
    if (this.curTitle == "")
      this.curTitle = getStats().title

    let hasUnseen = seenTitles.getNewCount() > 0
    local titlesData = this.titlesList.map(function(name) {
      let locText = loc($"title/{name}")
      let isOwn = this.isOwnTitle(name)
      return {
        name
        text = locText
        lowerText = utf8ToLower(locText)
        tooltipId = getTooltipType("UNLOCK_SHORT").getTooltipId(name)
        isCurrent = name == this.curTitle
        isLocked = !isOwn
        unseenIcon = isOwn && hasUnseen && seenTitles.isNew(name)
          && bhvUnseen.makeConfigStr(SEEN.TITLES, name)
      }
    }.bindenv(this))

    local titleWidth = getStringWidthPx(titlesData.map(@(t) t.text), "fontNormal", this.guiScene)
    if (hasUnseen)
      titleWidth += to_pixels("1@newWidgetIconHeight + 1@blockInterval")
    titleWidth = max(titleWidth + 2 * to_pixels("@buttonTextPadding"), to_pixels("1@buttonWidth"))
    let titleHeight = to_pixels("1@buttonHeight")
    let gRatioColumns = stdMath.calc_golden_ratio_columns(titlesData.len(),
      titleWidth / max(titleHeight, 1))
    let maxColumns = max((to_pixels("1@rw - 1@scrollBarSize") / titleWidth).tointeger(), 1)
    let columns = clamp(gRatioColumns, min(3, maxColumns), maxColumns)

    
    titlesData.sortby(@(a) a.lowerText)
    let orderedData = []
    let rows = ceil(titlesData.len().tofloat() / columns).tointeger()
    for (local i = 0; i < rows; i++)
      for (local j = i; j < titlesData.len(); j += rows)
        orderedData.append(titlesData[j])
    titlesData = orderedData
    this.titlesList = orderedData.map(@(t) t.name)

    return {
      hasTitles = this.titlesList.len() > 0
      titles = titlesData
      titleWidth = titleWidth
      titleColumns = columns
      value = this.titlesList.indexof(this.curTitle) ?? 0
    }
  }

  function initScreen() {
    move_mouse_on_child_by_value(this.scene.findObject("titles_list"))
    this.updateButtons()
  }

  isOwnTitle = @(title) this.ownTitles.contains(title)

  function getSelTitle(listObj) {
    if (!listObj?.isValid())
      return null

    return this.titlesList[listObj.getValue()]
  }

  function updateButtons() {
    let title = this.getSelTitle(this.scene.findObject("titles_list"))
    if (!title) {
      showObjById("btn_fav", false, this.scene)
      showObjById("btn_apply", false, this.scene)
      return
    }

    let isOwn = this.isOwnTitle(title)
    let favBtnObj = showObjById("btn_fav", !isOwn, this.scene)
    if (!isOwn)
      favBtnObj.setValue(isUnlockFav(title)
        ? loc("preloaderSettings/untrackProgress")
        : loc("preloaderSettings/trackProgress"))

    showObjById("btn_apply", isOwn, this.scene)
  }

  function onTitleSelect(obj) {
    let title = this.getSelTitle(obj)
    if (this.isOwnTitle(title)) {
      seenTitles.markSeen(title)
      let titleObj = obj.getChild(obj.getValue())
      titleObj.hasUnseenIcon = "no"
    }

    this.updateButtons()
  }

  function onTitleActivate(obj) {
    let title = this.getSelTitle(obj)
    if (this.isOwnTitle(title)) {
      this.setTitleAndGoBack(title)
      return
    }

    toggleUnlockFav(title)
    this.updateButtons()
  }

  function onTitleClick(obj) {
    let title = this.getSelTitle(obj)
    if (this.isOwnTitle(title))
      this.setTitleAndGoBack(title)
  }

  function onTitleClear() {
    this.setTitleAndGoBack("")
  }

  function onApply() {
    let title = this.getSelTitle(this.scene.findObject("titles_list"))
    this.setTitleAndGoBack(title)
  }

  function onToggleFav() {
    let title = this.getSelTitle(this.scene.findObject("titles_list"))
    toggleUnlockFav(title)
    this.updateButtons()
  }

  function setTitleAndGoBack(titleName) {
    if (!titleName || titleName == this.curTitle)
      return this.goBack()

    if (this.onCompleteFunc) {
      this.onCompleteFunc(titleName)
      this.goBack()
      return
    }

    addTask(
      select_current_title(titleName),
      {
        showProgressBox = true
        progressBoxText = loc("charServer/checking")
      },
      function() {
        clearStats()
        getStats()
      })

    this.goBack()
  }

  function afterModalDestroy() {
    seenTitles.markSeen()
  }
}
register_gui_handler("ChooseTitle", ChooseTitle)

return freeze({ ChooseTitle })
