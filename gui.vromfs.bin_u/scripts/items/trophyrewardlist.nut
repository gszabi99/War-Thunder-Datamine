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

  function initScreen()
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return goBack()

    local titleObj = scene.findObject("title")
    if (::check_obj(titleObj))
      titleObj.setValue(::loc(tittleLocId))

    if (rewardsArray.len() > 3)
      listObj.width = (listObj.getSize()[0] + guiScene.calcString("1@scrollBarSize", null)).tostring()

    fillList(listObj)
    listObj.select()
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
    local infoObj = showSceneBtn("item_info", isItem)
    local infoTextObj = showSceneBtn("item_info_text", !isItem)
    if (isItem)
    {
      if (!::check_obj(infoObj))
        return

      local item = ::ItemsManager.findItemById(reward_config.item)
      ::ItemsManager.fillItemDescr(item, infoObj, this, true, true, reward_config)
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
    listObj.select()
    if (listObj.childrenCount() > 0 && listObj.getValue() < 0)
      listObj.setValue(0)
  }
}
