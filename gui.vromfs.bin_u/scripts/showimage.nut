from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")


const MAX_TEXTURE_SIZE_IN_ATLAS = 512

::view_fullscreen_image <- function view_fullscreen_image(obj) {
  handlersManager.loadHandler(gui_handlers.ShowImage, { showObj = obj })
}

gui_handlers.ShowImage <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showImage.blk"

  showObj = null
  baseSize = null
  maxSize = null
  basePos = null
  lastPos = null
  imgObj = null
  frameObj = null
  shadeObj = null

  resizeTime = 0.2
  timer = 0.0
  moveBack = false

  function initScreen() {
    if (!checkObj(this.showObj))
      return this.goBack()

    let image = this.showObj?["background-image"]
    this.maxSize = [
      toPixels(this.guiScene, this.showObj?["max-width"]  ?? "@rw", this.showObj),
      toPixels(this.guiScene, this.showObj?["max-height"] ?? "@rh", this.showObj)
    ]

    if (!image || image == "" || !this.maxSize[0] || !this.maxSize[1])
      return this.goBack()

    this.scene.findObject("image_update").setUserData(this)

    this.baseSize = this.showObj.getSize()
    this.basePos = this.showObj.getPosRC()
    let rootSize = this.guiScene.getRoot().getSize()
    this.basePos = [this.basePos[0] + this.baseSize[0] / 2, this.basePos[1] + this.baseSize[1] / 2]
    this.lastPos = [rootSize[0] / 2, rootSize[1] / 2]

    local sizeKoef = 1.0
    if (this.maxSize[0] > 0.9 * rootSize[0])
      sizeKoef = 0.9 * rootSize[0] / this.maxSize[0]
    if (this.maxSize[1] > 0.9 * rootSize[1]) {
      let koef2 = 0.9 * rootSize[1] / this.maxSize[1]
      if (koef2 < sizeKoef)
        sizeKoef = koef2
    }
    if (sizeKoef < 1.0) {
      this.maxSize[0] = (this.maxSize[0] * sizeKoef).tointeger()
      this.maxSize[1] = (this.maxSize[1] * sizeKoef).tointeger()
    }

    this.imgObj = this.scene.findObject("image")
    this.imgObj["max-width"] = this.maxSize[0].tostring()
    this.imgObj["max-height"] = this.maxSize[1].tostring()
    this.imgObj["background-image"] = image
    this.imgObj["background-svg-size"] = format("%d, %d", this.maxSize[0], this.maxSize[1])
    this.imgObj["background-repeat"] = this.showObj?["background-repeat"] ?? "aspect-ratio"

    this.frameObj = this.scene.findObject("imgFrame")
    this.shadeObj = this.scene.findObject("root-box")
    this.onUpdate(null, 0.0)
  }

  function countProp(baseVal, maxVal, t) {
    local div = maxVal - baseVal
    div *= 1.0 - (t - 1) * (t - 1)
    return (baseVal + div).tointeger().tostring()
  }

  function onUpdate(_obj, dt) {
    if (this.frameObj && this.frameObj.isValid()
        && ((!this.moveBack && this.timer < this.resizeTime) || (this.moveBack && this.timer > 0))) {
      this.timer += this.moveBack ? -dt : dt
      local t = this.timer / this.resizeTime
      if (t >= 1.0) {
        t = 1.0
        this.timer = this.resizeTime
        this.scene.findObject("btn_back").show(true)
      }
      if (this.moveBack && t <= 0.0) {
        t = 0.0
        this.timer = 0.0
        this.goBack() //performDelayed inside
      }

      this.imgObj.width = this.countProp(this.baseSize[0], this.maxSize[0], t)
      this.imgObj.height = this.countProp(this.baseSize[1], this.maxSize[1], t)
      this.frameObj.left = "".concat(this.countProp(this.basePos[0], this.lastPos[0], t), "-50%w")
      this.frameObj.top = "".concat(this.countProp(this.basePos[1], this.lastPos[1], t), "-50%h")
      this.shadeObj["transparent"] = (100 * t).tointeger().tostring()
    }
  }

  function onBack() {
    if (!this.moveBack) {
      this.moveBack = true
      this.scene.findObject("btn_back").show(false)
    }
  }
}

/*
 * image   @string - full path to image
 * ratio   @float  - image width/height ratio (default = 1)
 * maxSize @array|@integer - max size in pixels. Array ([w, h]) or integer (used for both sides) (0 = unlimited).
 **/
function guiStartImageWnd(image = null, ratio = 1, maxSize = 0) {
  if (u.isEmpty(image))
    return

  let params = { image, ratio, maxSize }
  let hClass = gui_handlers.ShowImageSimple
  let handler = handlersManager.findHandlerClassInScene(hClass)
  if (handler == null)
    handlersManager.loadHandler(hClass, params)
  else
    handler.reinitScreen(params)
}

gui_handlers.ShowImageSimple <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showImage.blk"

  image = null
  ratio = 1
  maxSize = 0

  function initScreen() {
    let rootObj = this.scene.findObject("root-box")
    if (!checkObj(rootObj))
      return this.goBack()

    rootObj["transparent"] = "100"

    let frameObj = rootObj.findObject("imgFrame")
    frameObj.pos = "50%pw-50%w, 45%ph-50%h"

    let imgObj = frameObj.findObject("image")
    if (!checkObj(imgObj))
      return this.goBack()

    if (!this.maxSize)
      this.maxSize = [ toPixels(this.guiScene, "@rw"), toPixels(this.guiScene, "@rh") ]
    else if (u.isInteger(this.maxSize))
      this.maxSize = [ this.maxSize, this.maxSize ]

    let height = screen_height() / 1.5
    local size = [ this.ratio * height, height ]

    if (size[0] > this.maxSize[0] || size[1] > this.maxSize[1]) {
      let maxSizeRatio = this.maxSize[0] * 1.0 / this.maxSize[1]
      if (maxSizeRatio > this.ratio)
        size = [ this.ratio * this.maxSize[1], this.maxSize[1] ]
      else
        size = [ this.maxSize[0], this.maxSize[0] / this.ratio ]
    }

    let isSvg = this.image.contains(".svg")

    imgObj["background-image"] = this.image
    imgObj.width  = format("%d", size[0])
    imgObj.height = format("%d", size[1])
    if (isSvg) {
      let isForAtlas = this.image.contains("gameuiskin#")
      let texSize = isForAtlas
        ? size.map(@(d) min(d, MAX_TEXTURE_SIZE_IN_ATLAS))
        : size
      imgObj["background-svg-size"] = format("%d, %d", texSize[0], texSize[1])
    }
    imgObj["background-repeat"] = "aspect-ratio"

    this.scene.findObject("btn_back").show(true)
  }

  function reinitScreen(params = {}) {
    this.setParams(params)
    this.initScreen()
  }

  function onBack() {
    this.goBack()
  }
}

return {
  guiStartImageWnd
}
