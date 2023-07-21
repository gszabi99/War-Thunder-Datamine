//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let persistent = { encyclopediaData = [] }

registerPersistentData("EncyclopediaGlobals", persistent, ["encyclopediaData"])

let initEncyclopediaData = function() {
  if (persistent.encyclopediaData.len() || !hasFeature("Encyclopedia"))
    return

  let blk = DataBlock()
  blk.load("config/encyclopedia.blk")

  let defSize = [blk.getInt("image_width", 10), blk.getInt("image_height", 10)]
  for (local chapterNo = 0; chapterNo < blk.blockCount(); chapterNo++) {
    let blkChapter = blk.getBlock(chapterNo)
    let name = blkChapter.getBlockName()

    if (::is_chinese_harmonized() && name == "history")
      continue

    let chapterDesc = {}
    chapterDesc.id <- name
    chapterDesc.articles <- []
    for (local articleNo = 0; articleNo < blkChapter.blockCount(); articleNo++) {
      let blkArticle = blkChapter.getBlock(articleNo)
      let showPlatform = blkArticle.getStr("showPlatform", "")
      let hidePlatform = blkArticle.getStr("hidePlatform", "")

      if ((showPlatform.len() > 0 && showPlatform != platformId)
          || hidePlatform == platformId)
        continue

      let articleDesc = {}
      articleDesc.id <- blkArticle.getBlockName()

      if (::is_vietnamese_version() && isInArray(articleDesc.id, ["historical_battles", "realistic_battles"]))
        continue

      articleDesc.haveHint <- blkArticle.getBool("haveHint", false)

      if (blkArticle?.images != null) {
        let imgList = blkArticle.images % "image"
        if (imgList.len() > 0) {
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


let open = function() {
  initEncyclopediaData()

  if (persistent.encyclopediaData.len() == 0)
    return

  ::gui_start_modal_wnd(::gui_handlers.Encyclopedia)
}

::gui_handlers.Encyclopedia <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  menuConfig = null
  curChapter = null

  function initScreen() {
    reqUnlockByClient("view_encyclopedia")

    let blockObj = this.scene.findObject("chapter_include_block")
    if (checkObj(blockObj))
      blockObj.show(true)

    let view = { tabs = [] }
    foreach (idx, chapter in persistent.encyclopediaData)
      view.tabs.append({
        id = chapter.id
        tabName = "#encyclopedia/" + chapter.id
        navImagesText = ::get_navigation_images_text(idx, persistent.encyclopediaData.len())
      })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let chaptersObj = this.scene.findObject("chapter_top_list")
    this.guiScene.replaceContentFromText(chaptersObj, data, data.len(), this)
    chaptersObj.on_select = "onChapterSelect"
    chaptersObj.show(true)
    chaptersObj.setValue(0)
    this.onChapterSelect(chaptersObj)

    let canShowLinkButtons = !::is_chinese_harmonized() && hasFeature("AllowExternalLink")
    foreach (btn in ["faq", "support", "wiki"])
      this.showSceneBtn("button_" + btn, canShowLinkButtons)
    ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function onChapterSelect(obj) {
    if (!checkObj(obj))
      return

    let value = obj.getValue()
    if (!(value in persistent.encyclopediaData))
      return

    let objArticles = this.scene.findObject("items_list")
    if (!checkObj(objArticles))
      return

    this.curChapter = persistent.encyclopediaData[value]

    let view = { items = [] }
    foreach (idx, article in this.curChapter.articles)
      view.items.append({
        id = article.id
        isSelected = idx == 0
        itemText = (this.curChapter.id == "aircrafts") ? "#" + article.id + "_0" : "#encyclopedia/" + article.id
      })

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)

    this.guiScene.replaceContentFromText(objArticles, data, data.len(), this)
    ::move_mouse_on_child(objArticles, 0)
    objArticles.setValue(0)
    this.onItemSelect(objArticles)
  }

  function onItemSelect(_obj) {
    let list = this.scene.findObject("items_list")
    let index = list.getValue()
    if (!(index in this.curChapter.articles))
      return

    let article = this.curChapter.articles[index]
    let txtDescr = loc("encyclopedia/" + article.id + "/desc")
    let objDesc = this.scene.findObject("item_desc")
    objDesc.findObject("item_desc_text").setValue(txtDescr)
    objDesc.findObject("item_name").setValue(loc("encyclopedia/" + article.id))

    let objImgDiv = this.scene.findObject("div_before_text")
    local data = ""
    if ("images" in article) {
      let w = article.imgSize[0]
      let h = article.imgSize[1]
      let maxWidth = this.guiScene.calcString("1@rw", null).tointeger()
      let maxHeight = (maxWidth * (h.tofloat() / w)).tointeger()
      let sizeText = (w >= h) ? ["0.333p.p.p.w - 8@imgFramePad", h + "/" + w + "w"] : [w + "/" + h + "h", "0.333p.p.p.w - 8@imgFramePad"]
      foreach (imageName in article.images) {
        let image = "ui/slides/encyclopedia/" + imageName + ""
        data += format("imgFrame { img { width:t='%s'; height:t='%s'; max-width:t='%d'; max-height:t='%d'; " +
                       "background-image:t='%s'; click_to_resize:t='yes'; ButtonImg {}}} ",
                       sizeText[0], sizeText[1], maxWidth, maxHeight,
                       image)
      }
    }
    this.guiScene.replaceContentFromText(objImgDiv, data, data.len(), this)
  }

  function onItemDblClick() {}
}

return {
  open = open
}