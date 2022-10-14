from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


const MAX_TEXTURE_SIZE_IN_ATLAS = 512

::view_fullscreen_image <- function view_fullscreen_image(obj)
{
  ::handlersManager.loadHandler(::gui_handlers.ShowImage, { showObj = obj })
}

::gui_handlers.ShowImage <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    if (!checkObj(showObj))
      return goBack()

    let image = showObj?["background-image"]
    maxSize = [
      ::g_dagui_utils.toPixels(guiScene, showObj?["max-width"]  ?? "@rw", showObj),
      ::g_dagui_utils.toPixels(guiScene, showObj?["max-height"] ?? "@rh", showObj)
    ]

    if (!image || image=="" || !maxSize[0] || !maxSize[1])
      return goBack()

    scene.findObject("image_update").setUserData(this)

    baseSize = showObj.getSize()
    basePos = showObj.getPosRC()
    let rootSize = guiScene.getRoot().getSize()
    basePos = [basePos[0] + baseSize[0]/2, basePos[1] + baseSize[1]/2]
    lastPos = [rootSize[0]/2, rootSize[1]/2]

    local sizeKoef = 1.0
    if (maxSize[0] > 0.9*rootSize[0])
      sizeKoef = 0.9*rootSize[0] / maxSize[0]
    if (maxSize[1] > 0.9*rootSize[1])
    {
      let koef2 = 0.9*rootSize[1] / maxSize[1]
      if (koef2 < sizeKoef)
        sizeKoef = koef2
    }
    if (sizeKoef < 1.0)
    {
      maxSize[0] = (maxSize[0] * sizeKoef).tointeger()
      maxSize[1] = (maxSize[1] * sizeKoef).tointeger()
    }

    imgObj = scene.findObject("image")
    imgObj["max-width"] = maxSize[0].tostring()
    imgObj["max-height"] = maxSize[1].tostring()
    imgObj["background-image"] = image
    imgObj["background-svg-size"] = format("%d, %d", maxSize[0], maxSize[1])
    imgObj["background-repeat"] = showObj?["background-repeat"] ?? "aspect-ratio"

    frameObj = scene.findObject("imgFrame")
    shadeObj = scene.findObject("root-box")
    onUpdate(null, 0.0)
  }

  function countProp(baseVal, maxVal, t)
  {
    local div = maxVal - baseVal
    div *= 1.0 - (t - 1)*(t - 1)
    return (baseVal+ div).tointeger().tostring()
  }

  function onUpdate(obj, dt)
  {
    if (frameObj && frameObj.isValid()
        && ((!moveBack && timer < resizeTime) || (moveBack && timer > 0)))
    {
      timer += moveBack? -dt : dt
      local t = timer / resizeTime
      if (t >= 1.0)
      {
        t = 1.0
        timer = resizeTime
        scene.findObject("btn_back").show(true)
      }
      if (moveBack && t <= 0.0)
      {
        t = 0.0
        timer = 0.0
        goBack() //performDelayed inside
      }

      imgObj.width = countProp(baseSize[0], maxSize[0], t)
      imgObj.height = countProp(baseSize[1], maxSize[1], t)
      frameObj.left = countProp(basePos[0], lastPos[0], t) + "-50%w"
      frameObj.top = countProp(basePos[1], lastPos[1], t) + "-50%h"
      shadeObj["transparent"] = (100 * t).tointeger().tostring()
    }
  }

  function onBack()
  {
    if (!moveBack)
    {
      moveBack = true
      scene.findObject("btn_back").show(false)
    }
  }
}

/*
 * image   @string - full path to image
 * ratio   @float  - image width/height ratio (default = 1)
 * maxSize @array|@integer - max size in pixels. Array ([w, h]) or integer (used for both sides) (0 = unlimited).
 **/
::gui_start_image_wnd <- function gui_start_image_wnd(image = null, ratio = 1, maxSize = 0)
{
  if (::u.isEmpty(image))
    return

  let params = { image, ratio, maxSize }
  let hClass = ::gui_handlers.ShowImageSimple
  let handler = ::handlersManager.findHandlerClassInScene(hClass)
  if (handler == null)
    ::handlersManager.loadHandler(hClass, params)
  else
    handler.reinitScreen(params)
}

::gui_handlers.ShowImageSimple <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showImage.blk"

  image = null
  ratio = 1
  maxSize = 0

  function initScreen()
  {
    let rootObj = scene.findObject("root-box")
    if (!checkObj(rootObj))
      return goBack()

    rootObj["transparent"] = "100"

    let frameObj = rootObj.findObject("imgFrame")
    frameObj.pos = "50%pw-50%w, 45%ph-50%h"

    let imgObj = frameObj.findObject("image")
    if (!checkObj(imgObj))
      return goBack()

    if (!maxSize)
      maxSize = [ ::g_dagui_utils.toPixels(guiScene, "@rw"), ::g_dagui_utils.toPixels(guiScene, "@rh") ]
    else if (::u.isInteger(maxSize))
      maxSize = [ maxSize, maxSize ]

    let height = ::screen_height() / 1.5
    local size = [ ratio * height, height ]

    if (size[0] > maxSize[0] || size[1] > maxSize[1])
    {
      let maxSizeRatio = maxSize[0] * 1.0 / maxSize[1]
      if (maxSizeRatio > ratio)
        size = [ ratio * maxSize[1], maxSize[1] ]
      else
        size = [ maxSize[0], maxSize[0] / ratio ]
    }

    let isSvg = image.contains(".svg")

    imgObj["background-image"] = image
    imgObj.width  = format("%d", size[0])
    imgObj.height = format("%d", size[1])
    if (isSvg) {
      let isForAtlas = image.contains("gameuiskin#")
      let texSize = isForAtlas
        ? size.map(@(d) min(d, MAX_TEXTURE_SIZE_IN_ATLAS))
        : size
      imgObj["background-svg-size"] = format("%d, %d", texSize[0], texSize[1])
    }
    imgObj["background-repeat"] = "aspect-ratio"

    scene.findObject("btn_back").show(true)
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }

  function onBack()
  {
    goBack()
  }
}
