from "%scripts/dagui_library.nut" import *

let { round } = require("math")
let { format, split_by_chars } = require("string")
let { GUI } = require("%scripts/utils/configs.nut")
let { stripTags } = require("%sqstd/string.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")














let layersCfgParams = {
  x = {
    formatValue = "%.2fpw",
    defaultValue = "(pw-w)/2",
    returnParamName = "posX"
  }
  y = {
    formatValue = "%.2fph",
    defaultValue = "(ph-h)/2",
    returnParamName = "posY"
  }
  w = {
    formatValue = "%.2fpw",
    defaultValue = "pw",
    returnParamName = "width"
  }
  h = {
    formatValue = "%.2fph",
    defaultValue = "ph",
    returnParamName = "height"
  }
  position = {
    defaultValue = "absolute"
    returnParamName = "position"
  }
}

let iconLayer = @"iconLayer {
  {id} size:t='{size}'; pos:t='{posX},{posY}'; position:t='{pos}'
  background-image:t='{image}'; background-svg-size:t='{texSize}'; {props} }"

let LayersIconState = persist("LayersIconState", @() {config = null})

let LayersIcon = {
  function replaceIconByIconData(iconObj, iconData) {
    if (!iconObj?.isValid())
      return

    let guiScene = iconObj.getScene()
    guiScene.replaceContentFromText(iconObj, iconData, iconData.len(), null)
  }
}

LayersIcon.initConfigOnce <- function initConfigOnce(blk = null) {
  if (LayersIconState.config)
    return

  if (!blk)
    blk = GUI.get()
  let config = isDataBlock(blk?.layered_icons) ? convertBlk(blk.layered_icons) : {}
  if (!("styles" in config))
    config.styles <- {}
  if (!("layers" in config))
    config.layers <- {}
  LayersIconState.config = config
}

LayersIcon.refreshConfig <- function refreshConfig() {
  LayersIconState.config = null
  LayersIcon.initConfigOnce(null)
}

LayersIcon.getIconData <- function getIconData(iconStyle, image = null, ratio = null,
  defStyle = null, iconParams = null, iconConfig = null, containerSizePx = 0) {
  this.initConfigOnce()

  local data = ""
  let styles = LayersIconState.config.styles
  let styleCfg = iconConfig ? iconConfig
    : iconStyle && (iconStyle in styles) && styles[iconStyle]
  let defStyleCfg = defStyle && (defStyle in styles) && styles[defStyle]

  let usingStyle = styleCfg ? styleCfg : defStyleCfg
  if (usingStyle) {
    let layers = split_by_chars(usingStyle, "; ")
    foreach (layerName in layers) {
      local layerCfg = this.findLayerCfg(layerName)
      if (!layerCfg)
        continue

      let layerId = getTblValue("id", layerCfg, layerName)
      let layerParams = getTblValue(layerId, iconParams)
      if (layerParams) {
        layerCfg = clone layerCfg
        foreach (id, value in layerParams)
          layerCfg[id] <- value
      }

      if (getTblValue("type", layerCfg, "image") == "text")
        data = "".concat(data, LayersIcon.getTextDataFromLayer(layerCfg))
      else
        data = "".concat(data, LayersIcon.genDataFromLayer(layerCfg, "", containerSizePx))
    }
  }
  else if (image && image != "") {
    ratio = (ratio && ratio > 0) ? ratio : 1.0
    let size = (ratio == 1.0) ? "ph, ph"
      : (ratio > 1.0) ? format("ph, %.2fph", 1 / ratio)
      : format("%.2fph, ph", ratio)
    local texSize = size
    if (containerSizePx > 0) {
      let texSz = (ratio == 1.0) ? [ containerSizePx, containerSizePx ]
        : (ratio > 1.0) ? [ containerSizePx, 1 / ratio * containerSizePx ]
        : [ ratio * containerSizePx, containerSizePx ]
      texSize = ", ".join(texSz.map(@(v) round(v)))
    }
    data = iconLayer.subst({ id = "id:t='iconLayer0'", size, texSize,
      posX = "(pw-w)/2", posY = "(ph-h)/2",
      pos = "absolute", image, props = "" })
  }

  return data
}

LayersIcon.getCustomSizeIconData <- function getCustomSizeIconData(image, size, pos = null) {
  return iconLayer.subst({ id = "id:t='iconLayer0'", size, texSize = size,
    posX = pos?[0] ?? "(pw-w)/2", posY = pos?[1] ?? "(ph-h)/2",
    pos = "absolute", image, props = "" })
}

LayersIcon.findLayerCfg <- function findLayerCfg(id) {
  return "layers" in LayersIconState.config ? getTblValue(id.tolower(), LayersIconState.config.layers) : null
}

LayersIcon.findStyleCfg <- function findStyleCfg(id) {
  return "styles" in LayersIconState.config ? getTblValue(id.tolower(), LayersIconState.config?.styles) : null
}

function calcLayerBaseParams(layerCfg, containerSizePx) {
  let res = {}

  foreach (paramName, table in layersCfgParams) {
    local result = table?.defaultValue ?? ""
    if (paramName in layerCfg) {
      if (type(layerCfg[paramName]) == "string")
        result = layerCfg[paramName]
      else if ("formatValue" in table)
        result = format(table.formatValue, layerCfg[paramName].tofloat())
    }
    res[table.returnParamName] <- result
  }

  local texW = res.width
  local texH = res.height
  if (containerSizePx > 0 && is_numeric(layerCfg?.w) && is_numeric(layerCfg?.h)) {
    texW = round((layerCfg?.w ?? 1.0) * containerSizePx)
    texH = round((layerCfg?.h ?? 1.0) * containerSizePx)
  }
  res.texSize <- $"{texW}, {texH}"

  return res
}

LayersIcon.genDataFromLayer <- function genDataFromLayer(layerCfg, insertLayers = "", containerSizePx = 0) {  
                                     
  let baseParams = calcLayerBaseParams(layerCfg, containerSizePx)

  let offsetX = getTblValue("offsetX", layerCfg, "")
  let offsetY = getTblValue("offsetY", layerCfg, "")

  let id = getTblValue("id", layerCfg) ? "".concat("id:t='", layerCfg.id, "';") : ""
  let img = getTblValue("img", layerCfg, "")

  local props = []
  foreach (key in [ "background-svg-size" ])
    if (key in layerCfg)
      props.append($"{key}:t='{layerCfg[key]}';")
  props = "".join(props)

  return iconLayer.subst({
    id,
    size = $"{baseParams.width}, {baseParams.height}",
    texSize = $"{baseParams.texSize}",
    posX = baseParams.posX + offsetX, posY = baseParams.posY + offsetY,
    pos = baseParams.position, image = img, props = $"{props} {insertLayers}" })
}


LayersIcon.genInsertedDataFromLayer <- function genInsertedDataFromLayer(mainLayerCfg, insertLayersArrayCfg) {
  local insertLayers = ""
  foreach (layerCfg in insertLayersArrayCfg)
    if (layerCfg) {
      if (getTblValue("type", layerCfg, "image") == "text")
        insertLayers = "".concat(insertLayers, LayersIcon.getTextDataFromLayer(layerCfg))
      else
        insertLayers = "".concat(insertLayers, LayersIcon.genDataFromLayer(layerCfg))
    }

  return LayersIcon.genDataFromLayer(mainLayerCfg, insertLayers)
}

LayersIcon.replaceIcon <- function replaceIcon(iconObj, iconStyle, image = null, ratio = null,
  defStyle = null, iconParams = null, iconConfig = null, containerSizePx = 0) {
  if (!checkObj(iconObj))
    return

  let guiScene = iconObj.getScene()
  let data = this.getIconData(iconStyle, image, ratio, defStyle, iconParams, iconConfig, containerSizePx)
  guiScene.replaceContentFromText(iconObj, data, data.len(), null)
}

LayersIcon.getTextDataFromLayer <- function getTextDataFromLayer(layerCfg) {
  let props = [format("color:t='%s';", getTblValue("color", layerCfg, "@commonTextColor"))]
  props.append(format("font:t='%s';", getTblValue("font", layerCfg, "@fontNormal")))
  foreach (id in ["font-ht", "max-width", "text-align", "shadeStyle"])
    if (id in layerCfg)
      props.append(format("%s:t='%s';", id, layerCfg[id]))

  let idTag = ("id" in layerCfg) ? format("id:t='%s';", stripTags(layerCfg.id)) : ""

  let posX = ("x" in layerCfg) ? layerCfg.x.tostring() : "(pw-w)/2"
  let posY = ("y" in layerCfg) ? layerCfg.y.tostring() : "(ph-h)/2"
  let position = getTblValue("position", layerCfg, "absolute")

  return format("blankTextArea {%s text:t='%s'; pos:t='%s, %s'; position:t='%s'; %s}",
                      idTag,
                      stripTags(getTblValue("text", layerCfg, "")),
                      posX, posY,
                      position,
                      "".join(props))
}

LayersIcon.getOffset <- @(itemsLen, minOffset, maxOffset) itemsLen <= 1 ? 0 : max(minOffset, maxOffset / (itemsLen - 1))

return {LayersIcon = freeze(LayersIcon)}
