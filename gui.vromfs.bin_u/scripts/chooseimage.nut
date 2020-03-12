local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
local seenList = ::require("scripts/seen/seenList.nut")
local stdMath = require("std/math.nut")

/*
  config = {
    options = [{ image = img1 }, { image = img2, height = 50 }]
    tooltipObjFunc = function(obj, value)  - function to generate custom tooltip for item.
                                             must return bool if filled correct
    value = 0
  }
*/
::gui_choose_image <- function gui_choose_image(config, applyFunc, owner)
{
  ::handlersManager.loadHandler(::gui_handlers.ChooseImage, {
                                  config = config
                                  owner = owner
                                  applyFunc = applyFunc
                                })
}

class ::gui_handlers.ChooseImage extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chooseImage/chooseImage.blk"

  config = null
  options = null
  owner = null
  applyFunc = null
  choosenValue = null

  currentPage  = -1
  itemsPerPage = 1
  valueInited = false
  isPageFill = false
  imageButtonSize = "1@avatarButtonSize"
  imageButtonInterval = 0
  minAmountButtons = 8

  value = -1
  contentObj = null

  function initScreen()
  {
    if (!config || !("options" in config))
      return goBack()

    options = []
    local configValue = ("value" in config)? config.value : -1
    foreach(idx, option in config.options)
    {
      local isVisible = ::getTblValue("show", option, true)
      if (!isVisible)
        continue

      if (value < 0 || idx == configValue)
        value = options.len()
      options.append(option)
    }

    initItemsPerPage()

    currentPage = ::max(0, (value / itemsPerPage).tointeger())

    contentObj = scene.findObject("images_list")
    contentObj.select()
    fillPage()

    showSceneBtn("btn_select", ::show_console_buttons)
  }

  function initItemsPerPage()
  {
    guiScene.applyPendingChanges(false)
    local listObj = scene.findObject("images_list")
    local cfg = ::g_dagui_utils.countSizeInItems(listObj, imageButtonSize, imageButtonSize, imageButtonInterval, imageButtonInterval)

    //update size for single page
    if (cfg.itemsCountX * cfg.itemsCountY > options.len())
    {
      local total = ::max(options.len(), minAmountButtons)
      local columns = ::min(stdMath.calc_golden_ratio_columns(total), cfg.itemsCountX)
      local rows = ::ceil(total.tofloat() / columns).tointeger()
      if (rows > cfg.itemsCountY)
      {
        rows = cfg.itemsCountY
        columns = ::ceil(total.tofloat() / rows).tointeger()
      }
      cfg.itemsCountX = columns
      cfg.itemsCountY = rows
    }

    ::g_dagui_utils.adjustWindowSizeByConfig(scene.findObject("wnd_frame"), listObj, cfg)
    itemsPerPage = cfg.itemsCountX * cfg.itemsCountY
  }

  function fillPage()
  {
    local view = {
      avatars = []
    }

    local haveCustomTooltip = getTooltipObjFunc() != null
    local start = currentPage * itemsPerPage
    local end = ::min((currentPage + 1) * itemsPerPage, options.len()) - 1
    local selIdx = valueInited ? ::min(contentObj.getValue(), end - start)
      : ::clamp(value - start, 0, end - start)
    for (local i = start; i <= end; i++)
    {
      local item = options[i]
      local avatar = {
        id          = i
        avatarImage = item.image
        enabled     = item.enabled
        haveCustomTooltip = haveCustomTooltip
        tooltipId   = haveCustomTooltip ? null : ::getTblValue("tooltipId", item)
        unseenIcon = item?.seenListId && bhvUnseen.makeConfigStr(item?.seenListId, item?.seenEntity)
      }
      view.avatars.append(avatar)
    }

    isPageFill = true
    local blk = ::handyman.renderCached("gui/avatars", view)
    guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    updatePaginator()

    contentObj.setValue(selIdx)
    valueInited = true
    isPageFill = false

    updateButtons()
  }

  function updatePaginator()
  {
    local paginatorObj = scene.findObject("paginator_place")
    ::generatePaginator(paginatorObj, this, currentPage, (options.len() - 1) / itemsPerPage)

    local prevUnseen = currentPage ? getSeenConfig(0, currentPage * itemsPerPage - 1) : null
    local nextFirstIdx = (currentPage + 1) * itemsPerPage
    local nextUnseen = nextFirstIdx >= options.len() ? null
      : getSeenConfig(nextFirstIdx, options.len() - 1)
    ::paginator_set_unseen(paginatorObj,
      prevUnseen && bhvUnseen.makeConfigStr(prevUnseen.listId, prevUnseen.entities),
      nextUnseen && bhvUnseen.makeConfigStr(nextUnseen.listId, nextUnseen.entities))
  }

  function goToPage(obj)
  {
    markCurPageSeen()
    currentPage = obj.to_page.tointeger()
    fillPage()
  }

  function chooseImage(idx)
  {
    choosenValue = idx
    goBack()
  }

  function onImageChoose(obj)
  {
    if (obj)
      chooseImage(obj.id.tointeger())
  }

  function onImageSelect()
  {
    if (isPageFill)
      return

    updateButtons()
    local item = options?[getSelIconIdx()]
    if (item?.seenListId)
      seenList.get(item.seenListId).markSeen(item?.seenEntity)
  }

  function onChoose()
  {
    local selIdx = getSelIconIdx()
    if (selIdx >= 0)
      chooseImage(getSelIconIdx())
  }

  function getSelIconIdx()
  {
    if (!::checkObj(contentObj))
      return -1
    return contentObj.getValue() + currentPage * itemsPerPage
  }

  function updateButtons()
  {
    local option = ::getTblValue(getSelIconIdx(), options)
    showSceneBtn("btn_select", ::getTblValue("enabled", option, false))
  }

  function afterModalDestroy()
  {
    if (!applyFunc || choosenValue==null)
      return

    if (owner)
      applyFunc.call(owner, options[choosenValue])
    else
      applyFunc(options[choosenValue])
  }

  function getTooltipObjFunc()
  {
    return ::getTblValue("tooltipObjFunc", config)
  }

  function onImageTooltipOpen(obj)
  {
    local id = getTooltipObjId(obj)
    local func = getTooltipObjFunc()
    if (!id || !func)
      return

    local res = func(obj, id.tointeger())
    if (!res)
      obj["class"] = "empty"
  }

  function goBack()
  {
    markCurPageSeen()
    base.goBack()
  }

  function getSeenConfig(start, end)
  {
    local res = {
      listId = null
      entities = []
    }
    for(local i = end; i >= start; i--)
    {
      local item = options[i]
      if (!item?.seenListId || !item?.seenEntity)
        continue

      res.listId = item.seenListId
      res.entities.append(item.seenEntity)
    }
    return res.listId ? res : null
  }

  function markCurPageSeen()
  {
    local seenConfig = getSeenConfig(currentPage * itemsPerPage,
      ::min((currentPage + 1) * itemsPerPage, options.len()) - 1)
    if (seenConfig)
      seenList.get(seenConfig.listId).markSeen(seenConfig.entities)
  }
}
