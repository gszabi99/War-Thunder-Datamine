/* LayersIcon API:
  getIconData(iconStyle, image = null, ratio = null, defStyle = null, iconParams = null)
                        - get icon data for replace content
  replaceIcon(iconObj, iconStyle, image=null, ratio=null, defStyle = null, iconParams = null)
                        - find icon data and replace content it in iconObj
  genDataFromLayer(layerCfg)  - generate data for replace content by layer config
                        - params:
                            w, h  - (float) width and height as part of parent size  (default: equal parent size)
                            x, y  - position as part of parent (default: in the middle)
                            img = image
                            id = layer id
*/

::LayersIcon <- {
  [PERSISTENT_DATA_PARAMS] = ["config"]

  config = null
  iconLayer = @"iconLayer {
    {id} size:t='{size}'; pos:t='{posX},{posY}'; position:t='{pos}'
    background-image:t='{image}'; background-svg-size:t='{size}'; {props} }"
  layersCfgParams = {
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
}

LayersIcon.initConfigOnce <- function initConfigOnce(blk = null)
{
  if (config)
    return

  if (!blk)
    blk = ::configs.GUI.get()
  config = blk?.layered_icons ? ::buildTableFromBlk(blk.layered_icons) : {}
  if (!("styles" in config)) config.styles <- {}
  if (!("layers" in config)) config.layers <- {}
}

LayersIcon.refreshConfig <- function refreshConfig()
{
  ::LayersIcon.config = null
  ::LayersIcon.initConfigOnce(null)
}

LayersIcon.getIconData <- function getIconData(iconStyle, image=null, ratio=null, defStyle=null, iconParams=null, iconConfig=null)
{
  initConfigOnce()

  local data = ""
  local styleCfg = iconConfig ? iconConfig
    : iconStyle && (iconStyle in config.styles) && config.styles[iconStyle]
  local defStyleCfg = defStyle && (defStyle in config.styles) && config.styles[defStyle]

  local usingStyle = styleCfg? styleCfg : defStyleCfg
  if (usingStyle)
  {
    local layers = split(usingStyle, "; ")
    foreach (layerName in layers)
    {
      local layerCfg = findLayerCfg(layerName)
      if (!layerCfg)
        continue

      local layerId = ::getTblValue("id", layerCfg, layerName)
      local layerParams = ::getTblValue(layerId, iconParams)
      if (layerParams)
      {
        layerCfg = clone layerCfg
        foreach (id, value in layerParams)
          layerCfg[id] <- value
      }

      if (::getTblValue("type", layerCfg, "image") == "text")
        data += ::LayersIcon.getTextDataFromLayer(layerCfg)
      else
        data += ::LayersIcon.genDataFromLayer(layerCfg)
    }
  }
  else if (image && image != "")
  {
    ratio = (ratio && ratio > 0) ? ratio : 1.0
    local size = (ratio == 1.0)? "ph, ph" : (ratio > 1.0)? format("ph, %.2fph", 1/ratio) : format("%.2fph, ph", ratio)
    data = iconLayer.subst({ id = "id:t='iconLayer0'", size, posX ="(pw-w)/2", posY = "(ph-h)/2",
      pos = "absolute", image, props = "" })
  }

  return data
}

LayersIcon.getCustomSizeIconData <- function getCustomSizeIconData(image, size)
{
  return iconLayer.subst({ id = "id:t='iconLayer0'", size, posX = "(pw-w)/2", posY = "(ph-h)/2",
    pos = "absolute", image, props = "" })
}

LayersIcon.findLayerCfg <- function findLayerCfg(id)
{
  return "layers" in config ? ::getTblValue(id.tolower(), config.layers) : null
}

LayersIcon.findStyleCfg <- function findStyleCfg(id)
{
  return "styles" in config ? ::getTblValue(id.tolower(), config?.styles) : null
}

LayersIcon.genDataFromLayer <- function genDataFromLayer(layerCfg, insertLayers = "")  //need to move it to handyman,
                                     //but before need to correct cashe it or it will decrease performance
{
  local getResultsTable = (@(layersCfgParams, layerCfg) function() {
    local resultTable = {}

    foreach(paramName, table in layersCfgParams)
    {
      local resultParamName = ::getTblValue("returnParamName", table)
      if (!resultParamName)
        continue

      local result = ::getTblValue("defaultValue", table, "")
      if (paramName in layerCfg)
      {
        if (typeof layerCfg[paramName] == "string")
          result = layerCfg[paramName]
        else if ("formatValue" in table)
          result = ::format(table.formatValue, layerCfg[paramName].tofloat())
      }

      resultTable[resultParamName] <- result
    }

    return resultTable
  })(layersCfgParams, layerCfg)

  local baseParams = getResultsTable()

  local offsetX = ::getTblValue("offsetX", layerCfg, "")
  local offsetY = ::getTblValue("offsetY", layerCfg, "")

  local id = ::getTblValue("id", layerCfg)? "id:t='" + layerCfg.id + "';" : ""
  local img = ::getTblValue("img", layerCfg, "")

  local props = ""
  foreach(key in [ "background-svg-size" ])
    if (key in layerCfg)
      props += ::format("%s:t='%s';", key, layerCfg[key])

  return iconLayer.subst({id, size = $"{baseParams.width}, {baseParams.height}",
    posX = baseParams.posX + offsetX, posY = baseParams.posY + offsetY,
    pos = baseParams.position, image = img, props = $"{props} {insertLayers}" })
}

// For icon customization it is much easier to use replaceIcon() with iconParams, or getIconData() with iconParams.
LayersIcon.genInsertedDataFromLayer <- function genInsertedDataFromLayer(mainLayerCfg, insertLayersArrayCfg)
{
  local insertLayers = ""
  foreach(layerCfg in insertLayersArrayCfg)
    if (layerCfg)
    {
      if (::getTblValue("type", layerCfg, "image") == "text")
        insertLayers += ::LayersIcon.getTextDataFromLayer(layerCfg)
      else
        insertLayers += ::LayersIcon.genDataFromLayer(layerCfg)
    }

  return ::LayersIcon.genDataFromLayer(mainLayerCfg, insertLayers)
}

LayersIcon.replaceIcon <- function replaceIcon(iconObj, iconStyle, image=null, ratio=null, defStyle=null, iconParams=null, iconConfig=null)
{
  if (!::checkObj(iconObj))
    return

  local guiScene = iconObj.getScene()
  local data = getIconData(iconStyle, image, ratio, defStyle, iconParams, iconConfig)
  guiScene.replaceContentFromText(iconObj, data, data.len(), null)
}

LayersIcon.getTextDataFromLayer <- function getTextDataFromLayer(layerCfg)
{
  local props = ::format("color:t='%s';", ::getTblValue("color", layerCfg, "@commonTextColor"))
  props += ::format("font:t='%s';", ::getTblValue("font", layerCfg, "@fontNormal"))
  foreach(id in ["font-ht", "max-width", "text-align", "shadeStyle"])
    if (id in layerCfg)
      props += ::format("%s:t='%s';", id, layerCfg[id])

  local idTag = ("id" in layerCfg) ? ::format("id:t='%s';", ::g_string.stripTags(layerCfg.id)) : ""

  local posX = ("x" in layerCfg)? layerCfg.x.tostring() : "(pw-w)/2"
  local posY = ("y" in layerCfg)? layerCfg.y.tostring() : "(ph-h)/2"
  local position = ::getTblValue("position", layerCfg, "absolute")

  return ::format("blankTextArea {%s text:t='%s'; pos:t='%s, %s'; position:t='%s'; %s}",
                      idTag,
                      ::g_string.stripTags(::getTblValue("text", layerCfg, "")),
                      posX, posY,
                      position,
                      props)
}

LayersIcon.getOffset <- @(itemsLen, minOffset, maxOffset) itemsLen <= 1 ? 0 : ::max(minOffset, maxOffset / (itemsLen - 1))

::g_script_reloader.registerPersistentDataFromRoot("LayersIcon")
