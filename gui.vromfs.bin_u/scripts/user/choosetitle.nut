let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let seenTitles = require("%scripts/seen/seenList.nut").get(SEEN.TITLES)
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let stdMath = require("%sqstd/math.nut")
let { UNLOCK_SHORT } = require("%scripts/utils/genericTooltipTypes.nut")

::gui_handlers.ChooseTitle <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/profile/chooseTitle"

  curTitle = ""
  ownTitles = null
  titlesList = null

  static function open()
  {
    if(!isInMenu() || !::my_stats.getStats())
      return

    ::handlersManager.loadHandler(::gui_handlers.ChooseTitle)
  }

  function getSceneTplView()
  {
    ownTitles = ::my_stats.getTitles()
    titlesList = ::g_unlocks.getAllUnlocksWithBlkOrder()
      .filter(@(u) u?.type == "title" && ::is_unlock_visible(u))
      .map(@(u) u.id)
    curTitle = ::my_stats.getStats().title

    let hasUnseen = seenTitles.getNewCount() > 0
    local titlesData = titlesList.map(function(name)
    {
      let locText = ::loc("title/" + name)
      let isOwn = isOwnTitle(name)
      return {
        name
        text = locText
        lowerText = ::g_string.utf8ToLower(locText)
        tooltipId = UNLOCK_SHORT.getTooltipId(name)
        isCurrent = name == curTitle
        isLocked = !isOwn
        unseenIcon = isOwn && hasUnseen && seenTitles.isNew(name)
          && bhvUnseen.makeConfigStr(SEEN.TITLES, name)
      }
    }.bindenv(this))

    local titleWidth = daguiFonts.getStringWidthPx(titlesData.map(@(t) t.text), "fontNormal", guiScene)
    if (hasUnseen)
      titleWidth += ::to_pixels("1@newWidgetIconHeight + 1@blockInterval")
    titleWidth = max(titleWidth + 2 * ::to_pixels("@buttonTextPadding"), ::to_pixels("1@buttonWidth"))
    let titleHeight = ::to_pixels("1@buttonHeight")
    let gRatioColumns = stdMath.calc_golden_ratio_columns(titlesData.len(),
      titleWidth / (titleHeight || 1))
    let maxColumns = (::to_pixels("1@rw - 1@scrollBarSize") / titleWidth ).tointeger() || 1
    let columns = clamp(gRatioColumns, min(3, maxColumns), maxColumns)

    //sort alphabetically, and by columns
    titlesData.sort(@(a, b) a.lowerText <=> b.lowerText)
    let orderedData = []
    let rows = ::ceil(titlesData.len().tofloat() / columns).tointeger()
    for(local i = 0; i < rows; i++)
      for(local j = i; j < titlesData.len(); j += rows)
        orderedData.append(titlesData[j])
    titlesData = orderedData
    titlesList = orderedData.map(@(t) t.name)

    return {
      hasTitles = titlesList.len() > 0
      titles = titlesData
      titleWidth = titleWidth
      titleColumns = columns
      value = titlesList.indexof(curTitle) ?? 0
    }
  }

  function initScreen()
  {
    ::move_mouse_on_child_by_value(scene.findObject("titles_list"))
    updateButtons()
  }

  isOwnTitle = @(title) ownTitles.contains(title)

  function getSelTitle(listObj) {
    if (!listObj?.isValid())
      return null

    return titlesList[listObj.getValue()]
  }

  function updateButtons() {
    let title = getSelTitle(scene.findObject("titles_list"))
    if (!title) {
      this.showSceneBtn("btn_fav", false)
      this.showSceneBtn("btn_apply", false)
      return
    }

    let isOwn = isOwnTitle(title)
    let favBtnObj = this.showSceneBtn("btn_fav", !isOwn)
    if (!isOwn)
      favBtnObj.setValue(::g_unlocks.isUnlockFav(title)
        ? ::loc("preloaderSettings/untrackProgress")
        : ::loc("preloaderSettings/trackProgress"))

    this.showSceneBtn("btn_apply", isOwn)
  }

  function toggleFav(unlockId) {
    if (!unlockId)
      return

    let isFav = ::g_unlocks.isUnlockFav(unlockId)
    if (isFav) {
      ::g_unlocks.removeUnlockFromFavorites(unlockId)
      updateButtons()
      return
    }

    if (!::g_unlocks.canAddFavorite()) {
      let num = ::g_unlocks.favoriteUnlocksLimit
      let msg = ::loc("mainmenu/unlockAchievements/limitReached", { num })
      this.msgBox("max_fav_count", msg, [["ok"]], "ok")
      return
    }

    ::g_unlocks.addUnlockToFavorites(unlockId)
    updateButtons()
  }

  function onTitleSelect(obj)
  {
    let title = getSelTitle(obj)
    if (isOwnTitle(title)) {
      seenTitles.markSeen(title)
      let titleObj = obj.getChild(obj.getValue())
      titleObj.hasUnseenIcon = "no"
    }

    updateButtons()
  }

  function onTitleActivate(obj) {
    let title = getSelTitle(obj)
    if (isOwnTitle(title))
      setTitleAndGoBack(title)
    else
      toggleFav(title)
  }

  function onTitleClick(obj) {
    let title = getSelTitle(obj)
    if (isOwnTitle(title))
      setTitleAndGoBack(title)
  }

  function onTitleClear() {
    setTitleAndGoBack("")
  }

  function onApply() {
    let title = getSelTitle(scene.findObject("titles_list"))
    setTitleAndGoBack(title)
  }

  function onToggleFav() {
    let title = getSelTitle(scene.findObject("titles_list"))
    toggleFav(title)
  }

  function setTitleAndGoBack(titleName) {
    if (!titleName || titleName == curTitle)
      return goBack()

    ::g_tasker.addTask(
      ::select_current_title(titleName),
      {
        showProgressBox = true
        progressBoxText = ::loc("charServer/checking")
      },
      function()
      {
       ::my_stats.clearStats()
       ::my_stats.getStats()
      })

    goBack()
  }

  function afterModalDestroy()
  {
    seenTitles.markSeen()
  }
}