local itemInfoHandler = require("scripts/items/itemInfoHandler.nut")

::gui_start_open_trophy_rewards_list <- function gui_start_open_trophy_rewards_list(params = {})
{
  local rewardsArray = params?.rewardsArray
  if (!rewardsArray || !rewardsArray.len())
    return

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardsList, params)
}

class ::gui_handlers.trophyRewardsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyRewardsList.blk"

  rewardsArray = []
  tittleLocId = "mainmenu/rewardsList"

  infoHandler = null

  function initScreen()
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return goBack()

    infoHandler = itemInfoHandler(scene.findObject("item_info"))

    local titleObj = scene.findObject("title")
    if (::check_obj(titleObj))
      titleObj.setValue(::loc(tittleLocId))

    fillList(listObj)

    if (rewardsArray.len() > 4)
      listObj.width = (listObj.getSize()[0] + ::to_pixels("1@scrollBarSize")).tostring()

    listObj.setValue(rewardsArray.len() > 0 ? 0 : -1)
    ::move_mouse_on_child_by_value(listObj)
  }

  function fillList(listObj)
  {
    local data = getItemsImages()
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function getItemsImages()
  {
    local data = ""
    foreach(idx, reward in rewardsArray)
      data += ::trophyReward.getImageByConfig(reward, false, "trophy_reward_place", true)

    return data
  }

  function updateItemInfo(obj)
  {
    local val = obj.getValue()
    local reward_config = rewardsArray[val]
    local isItem = reward_config?.item != null
    infoHandler?.setHandlerVisible(isItem)
    local infoTextObj = showSceneBtn("item_info_text", !isItem)
    if (isItem)
    {
      if (!infoHandler)
        return

      local item = ::ItemsManager.findItemById(reward_config.item)
      infoHandler.updateHandlerData(item, true, true, reward_config)
    } else
    {
      if (!::check_obj(infoTextObj))
        return

      local text = [::trophyReward.getName(reward_config)]
      text.append(::trophyReward.getDecription(reward_config, true))
      infoTextObj.setValue(::g_string.implode(text, "\n"))
    }
  }

  function onEventItemsShopUpdate(p)
  {
    local listObj = scene.findObject("items_list")
    if (!::check_obj(listObj))
      return

    fillList(listObj)
    if (listObj.childrenCount() > 0 && listObj.getValue() < 0)
      listObj.setValue(0)
    ::move_mouse_on_child_by_value(listObj)
  }
}
