local persistent = { encyclopediaData = [] }

::g_script_reloader.registerPersistentData("EncyclopediaGlobals", persistent, ["encyclopediaData"])

local initEncyclopediaData = function()
{
  if (persistent.encyclopediaData.len() || !::has_feature("Encyclopedia"))
    return

  local blk = ::DataBlock()
  blk.load("config/encyclopedia.blk")

  local defSize = [blk.getInt("image_width", 10), blk.getInt("image_height", 10)]
  for (local chapterNo = 0; chapterNo < blk.blockCount(); chapterNo++)
  {
    local blkChapter = blk.getBlock(chapterNo)
    local name = blkChapter.getBlockName()

    if (::is_vendor_tencent() && name == "history")
      continue

    local chapterDesc = {}
    chapterDesc.id <- name
    chapterDesc.articles <- []
    for (local articleNo = 0; articleNo < blkChapter.blockCount(); articleNo++)
    {
      local blkArticle = blkChapter.getBlock(articleNo)
      local showPlatform = blkArticle.getStr("showPlatform", "")
      local hidePlatform = blkArticle.getStr("hidePlatform", "")

      if ((showPlatform.len() > 0 && showPlatform != ::target_platform)
          || hidePlatform == ::target_platform)
        continue

      local articleDesc = {}
      articleDesc.id <- blkArticle.getBlockName()

      if (::is_vietnamese_version() && ::isInArray(articleDesc.id, ["historical_battles", "realistic_battles"]))
        continue

      articleDesc.haveHint <- blkArticle.getBool("haveHint",false)

      if (blkArticle?.images != null)
      {
        local imgList = blkArticle.images % "image"
        if (imgList.len() > 0)
        {
          articleDesc.images <- imgList
          articleDesc.imgSize <- [blkArticle.getInt("image_width", defSize[0]),
                                  blkArticle.getInt("image_height", defSize[1])]
        }
      }
      chapterDesc.articles.append(articleDesc)
    }
    persistent.encyclopediaData.append(chapterDesc)
  }
}


local open = function()
{
  initEncyclopediaData()

  if (persistent.encyclopediaData.len() == 0)
    return

  ::gui_start_modal_wnd(::gui_handlers.Encyclopedia)
}

class ::gui_handlers.Encyclopedia extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  menuConfig = null
  curChapter = null

  function initScreen()
  {
    ::req_unlock_by_client("view_encyclopedia", false)

    local blockObj = scene.findObject("chapter_include_block")
    if (::checkObj(blockObj))
      blockObj.show(true)

    local view = { tabs = [] }
    foreach(idx, chapter in persistent.encyclopediaData)
      view.tabs.append({
        id = chapter.id
        tabName = "#encyclopedia/" + chapter.id
        navImagesText = ::get_navigation_images_text(idx, persistent.encyclopediaData.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local chaptersObj = scene.findObject("chapter_top_list")
    guiScene.replaceContentFromText(chaptersObj, data, data.len(), this)
    chaptersObj.on_select = "onChapterSelect"
    chaptersObj.show(true)
    chaptersObj.setValue(0)
    onChapterSelect(chaptersObj)

    local canShowLinkButtons = !::is_vendor_tencent() && ::has_feature("AllowExternalLink")
    foreach(btn in ["faq", "support", "wiki"])
      showSceneBtn("button_" + btn, canShowLinkButtons)
    ::move_mouse_on_child_by_value(scene.findObject("items_list"))
  }

  function onChapterSelect(obj)
  {
    if (!::check_obj(obj))
      return

    local value = obj.getValue()
    if (!(value in persistent.encyclopediaData))
      return

    local objArticles = scene.findObject("items_list")
    if (!::check_obj(objArticles))
      return

    curChapter = persistent.encyclopediaData[value]

    local view = { items = [] }
    foreach(idx, article in curChapter.articles)
      view.items.append({
        id = article.id
        isSelected = idx == 0
        itemText = (curChapter.id == "aircrafts")? "#" + article.id + "_0" : "#encyclopedia/" + article.id
      })

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)

    guiScene.replaceContentFromText(objArticles, data, data.len(), this)
    ::move_mouse_on_child(objArticles, 0)
    objArticles.setValue(0)
    onItemSelect(objArticles)
  }

  function onItemSelect(obj)
  {
    local list = scene.findObject("items_list")
    local index = list.getValue()
    if (!(index in curChapter.articles))
      return

    local article = curChapter.articles[index]
    local txtDescr = ::loc("encyclopedia/" + article.id + "/desc")
    local objDesc = scene.findObject("item_desc")
    objDesc.findObject("item_desc_text").setValue(txtDescr)
    objDesc.findObject("item_name").setValue(::loc("encyclopedia/" + article.id))

    local objImgDiv = scene.findObject("div_before_text")
    local data = ""
    if ("images" in article)
    {
      local w = article.imgSize[0]
      local h = article.imgSize[1]
      local maxWidth = guiScene.calcString("1@rw", null).tointeger()
      local maxHeight = (maxWidth * (h.tofloat()/w)).tointeger()
      local sizeText = (w >= h)? ["0.333p.p.p.w - 8@imgFramePad", h + "/" + w + "w"] : [w + "/" + h + "h", "0.333p.p.p.w - 8@imgFramePad"]
      foreach(imageName in article.images)
      {
        local image = "ui/slides/encyclopedia/" + imageName + ".jpg"
        data += format("imgFrame { img { width:t='%s'; height:t='%s'; max-width:t='%d'; max-height:t='%d'; " +
                       " background-image:t='%s'; click_to_resize:t='yes' }} ",
                       sizeText[0], sizeText[1], maxWidth, maxHeight,
                       image)
      }
    }
    guiScene.replaceContentFromText(objImgDiv, data, data.len(), this)
  }

  function onItemDblClick() {}
}

return {
  open = open
}