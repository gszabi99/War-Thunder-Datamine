from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { platformId, is_gdk }  = require("%sqstd/platform.nut")
let { read_text_from_file, file_exists } = require("dagor.fs")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")


const DELIVER = "==== "
const MAX_SYMBOLS_IN_PAGE = 100000


function fillPages(txtToSplit, txtPages) {
  txtPages.append("")
  foreach (blockIdx, blockTxt in txtToSplit.split(DELIVER)) {
    let txt = blockIdx == 0 ? blockTxt : $"{DELIVER}{blockTxt}"
    let idx = txtPages.len() - 1
    if (txtPages[idx] == "" || txtPages[idx].len() + txt.len() < MAX_SYMBOLS_IN_PAGE)
      txtPages[idx] = $"{txtPages[idx]}{txt}"
    else
      txtPages.append(txt)
  }
}

let loadAndProcessText = @(fileName) fileName == null ? "" : read_text_from_file(fileName)

let licensesCfgList = [
  {
    id = "LICENSE"
    fileName = $"{platformId}/LICENSE-aces"
    locId = "mainmenu/license"
    isVisible = @() true
  }
  {
    id = "LICENSE_GDK"
    fileName = $"{platformId}/LICENSE-aces-gdk"
    locId = "mainmenu/licenseGdk"
    isVisible = @() is_gdk
  }
  {
    id = "LICENSE_CEFPROCESS"
    fileName = $"{platformId}/LICENSE-cefprocess"
    locId = "mainmenu/licenseCefprocess"
    isVisible = @() true
  }
  {
    id = "CREDITS"
    fileName = "%langTxt/credits.txt"
    locId = "mainmenu/btnCredits"
    isVisible = @() hasFeature("Credits")
  }
]

gui_handlers.LicenseHandler <- class (BaseGuiHandler) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/licenseFrame.blk"

  curCfgList = null
  curCfgIdx = 0
  curPage = 0
  txtPages = null

  function initScreen() {
    this.curCfgList = licensesCfgList.filter(@(cfg) cfg.isVisible() && file_exists(cfg.fileName))
    let total = this.curCfgList.len()
    let view = {
      tabs = this.curCfgList.map(@(v, idx) {
        id = idx
        tabName = loc(v.locId)
        selected = idx == 0
        navImagesText = getNavigationImagesText(idx, total)
      })
    }

    let tabNestObj = this.scene.findObject("license_tabs")
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabNestObj, data, data.len(), this)

    this.updateLicenseScreen()
  }

  function onTabChange(obj) {
    this.curCfgIdx = obj.getValue()
    this.updateLicenseScreen()
  }

  function updateLicenseScreen() {
    let cfg = this.curCfgList[this.curCfgIdx]
    let txtToSplit = loadAndProcessText(cfg.fileName)
    this.curPage = 0
    this.txtPages = []
    fillPages(txtToSplit, this.txtPages)
    this.updatePageContent()
  }

  function updatePageContent() {
    let textObj = this.scene.findObject("license_text")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    textObj.setValue($"{this.txtPages[this.curPage]}")

    let paginatorObj = this.scene.findObject("paginator_place")
    generatePaginator(paginatorObj, this, this.curPage, this.txtPages.len() - 1)
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.updatePageContent()
  }
}

return {
  openLicenseWindow = @() handlersManager.loadHandler(gui_handlers.LicenseHandler)
}
