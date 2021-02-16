local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local seenTitles = require("scripts/seen/seenList.nut").get(SEEN.TITLES)
local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local stdMath = require("std/math.nut")

class ::gui_handlers.ChooseTitle extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/profile/chooseTitle"

  align = "bottom"
  alignObj = null
  openTitlesListFunc = null

  curTitle = ""
  titlesList = null

  static function open(params)
  {
    if(!isInMenu() || !::my_stats.getStats())
      return

    ::handlersManager.loadHandler(::gui_handlers.ChooseTitle, params)
  }

  function getSceneTplView()
  {
    titlesList = clone ::my_stats.getTitles()
    curTitle = ::my_stats.getStats().title

    local hasUnseen = seenTitles.getNewCount() > 0
    local titlesData = titlesList.map(function(name)
    {
      local locText = ::loc("title/" + name)
      return {
        name = name
        text = locText
        lowerText = ::g_string.utf8ToLower(locText)
        tooltipId = ::g_tooltip_type.UNLOCK.getTooltipId(name)
        isSelected = name == curTitle
        unseenIcon = hasUnseen && bhvUnseen.makeConfigStr(SEEN.TITLES, name)
      }
    }.bindenv(this))

    local titleWidth = daguiFonts.getStringWidthPx(titlesData.map(@(t) t.text), "fontNormal", guiScene)
    if (hasUnseen)
      titleWidth += ::to_pixels("1@newWidgetIconHeight + 1@blockInterval")
    titleWidth = ::max(titleWidth + 2 * ::to_pixels("@buttonTextPadding"), ::to_pixels("1@buttonWidth"))
    local titleHeight = ::to_pixels("1@buttonHeight")
    local gRatioColumns = stdMath.calc_golden_ratio_columns(titlesData.len(),
      titleWidth / (titleHeight || 1))
    local maxColumns = (::to_pixels("1@rw - 1@scrollBarSize") / titleWidth ).tointeger() || 1
    local columns = ::clamp(gRatioColumns, ::min(3, maxColumns), maxColumns)

    //sort alphabetically, and by columns
    titlesData.sort(@(a, b) a.lowerText <=> b.lowerText)
    local orderedData = []
    local rows = ::ceil(titlesData.len().tofloat() / columns).tointeger()
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

      hasTitlesListButton = openTitlesListFunc != null
      hasApplyButton = ::show_console_buttons && titlesList.len() > 0
    }
  }

  function initScreen()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"),
      { margin = [0, ::to_pixels("@popupOffset")] })
    if (titlesList.len())
      ::move_mouse_on_child_by_value(scene.findObject("titles_list"))
  }

  function onTitleSelect(obj)
  {
    local title = titlesList?[obj.getValue()]
    if (title)
      seenTitles.markSeen(title)
  }

  function onChooseTitle(obj)
  {
    setTitleAndGoBack(obj.id)
  }

  function onActivateTitleList(obj)
  {
    if (titlesList.len())
      setTitleAndGoBack(titlesList?[obj.getValue()] ?? "")
  }

  function onApply()
  {
    onActivateTitleList(scene.findObject("titles_list"))
  }

  function setTitleAndGoBack(titleName)
  {
    if (titleName == curTitle)
      return goBack()

   ::g_tasker.addTask(
     ::select_current_title(titleName),
     {
      showProgressBox = true
      progressBoxText = ::loc("charServer/checking")
    },
    function ()
    {
      ::my_stats.clearStats()
      ::my_stats.getStats()
    })
    goBack()
  }

  function onFullTitlesList()
  {
    if (!openTitlesListFunc)
      return
    goBack()
    openTitlesListFunc()
  }

  function afterModalDestroy()
  {
    seenTitles.markSeen()
  }
}