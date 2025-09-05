let {getTexReplaceString, getTexSetString} = require("%globalScripts/iconRender/itemTexReplace.nut")
let { Color4 } = require("dagor.math")

















































let RENDER_PARAMS = @"ui/gameuiskin#render{
  itemName:t={itemName};animchar:t={animchar};autocrop:b=false;
  yaw:r={yaw};pitch:r={pitch};roll:r={roll};
  w:i={width};h:i={height};offset:p2={offset_x},{offset_y};scale:r={scale};
  outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};
  silhouetteHasShadow:b={silhouetteHasShadow};silhouetteMinShadow:r={silhouetteMinShadow};
  distance:r={distance};
  attachType:t={attachType};
  brightness:r={brightness};
  sun:c={sunColor};
  zenith:r={zenith};
  azimuth:r={azimuth};
  {forceRealTimeRenderIcon}
  {attachments}
  {hideNodes}
  {objTexReplaceRules}
  {objTexSetRules}
  {paintColor}
  {blendFactor}
  {shaderColors}
}.render"

let cachedPictures = {}

function getPicture(source) {
  local pic = cachedPictures?[source]
  if (pic)
    return pic
  pic = source
  cachedPictures[source] <- pic
  return pic
}

let getTMatrixString = @(m)
  "[{0}]".subst(" ".join(array(4).map(@(_, i) $"[{m[i].x}, {m[i].y}, {m[i].z}]")))

function getShaderColorsString(item) {
  let { shaderColors = null } = item
  if (shaderColors == null || type(shaderColors) != "table")
    return ""
  let list = []
  list.append("shaderColors{")
  foreach (name, value in shaderColors){
    if (type(value) == "array" && value.len() > 3)
      list.append($"{name}:p4={value[0]},{value[1]},{value[2]},{value[3]};")
  }
  list.append("}")
  return "".join(list)
}

let getColor4String = @(col) $"{col.a},{col.r},{col.g},{col.b}"
let getPoint4String = @(col) $"{col.x},{col.y},{col.z},{col.w}"

let transparentTxt = getColor4String(Color4(0,0,0,0))
let silverTxt = getColor4String(Color4(192,192,192,200))
let whiteTxt = getColor4String(Color4(255, 255, 255, 255))

function iconWidget(item, params = {}, iconAttachments = null) {
  if ((item?.iconName ?? "") == "")
    return ""

  let {
    width = 64
    height = 64
    forceRealTimeRenderIcon = false
  } = params

  let shading = item?.shading ?? params?.shading ?? "full"

  let { iconName = "",
    itemName = "",
    itemTemplate = ""
    paintColor = null
    hideNodes = []
  } = item

  let outlineColor = item?.outlineColor ? getColor4String(item.outlineColor) : transparentTxt
  let outlineColorInactive = item?.outlineInactiveColor
    ? getColor4String(item.outlineInactiveColor) : transparentTxt
  let silhouetteColor = item?.silhouetteColor ? getColor4String(item.silhouetteColor) : silverTxt
  let silhouetteColorInactive = item?.silhouetteInactiveColor
    ? getColor4String(item.silhouetteInactiveColor) : silverTxt

  let imageHeight = height.tointeger()
  let imageWidth = width.tointeger()
  let zenith = item?.lightZenith ?? 65
  let azimuth = item?.lightAzimuth ?? -40
  let objTexReplace = getTexReplaceString(item)
  let objTexSet = getTexSetString(item)
  let shaderColors = getShaderColorsString(item)

  let sunColor = item?.sunColor ? getColor4String(item.sunColor) : whiteTxt

  let haveActiveAttachments = iconAttachments != null
  let attachments = []
  foreach (i, attachment in iconAttachments ?? []) {
    attachments.append($"a{i}\{animchar:t={attachment?.animchar};slot:t={attachment?.slot};scale:r={attachment?.scale ?? 1.0};outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};\}")
  }
  foreach (decorator in item?.decorators ?? []) {
    attachments.append($"a\{relativeTm:m={getTMatrixString(decorator?.relativeTm)};animchar:t={decorator?.animchar};parentNode:t={decorator?.nodeName};shading:t=same;attachType:t=node;swapYZ:b={decorator?.swapYZ ?? true};\}")
  }

  let hideNodesTex = hideNodes.map(@(node) $"node:t={node};")
  let paintColorParam = paintColor ? $"paintColor:p4={getPoint4String(paintColor)}" : ""
  let needEnableRTRender = forceRealTimeRenderIcon == "" || itemTemplate == forceRealTimeRenderIcon

  let imageSource = RENDER_PARAMS.subst({
    itemName
    animchar = iconName
    yaw = item?.iconYaw ?? 0
    pitch = item?.iconPitch ?? 0
    roll = item?.iconRoll ?? 0
    width = imageWidth
    height = imageHeight
    offset_x = item?.iconOffsX ?? 0
    offset_y = item?.iconOffsY ?? 0
    scale = item?.iconScale ?? 1
    distance = item?.distance ?? 4.0
    outlineColor = haveActiveAttachments ? outlineColorInactive : outlineColor
    silhouetteColor = haveActiveAttachments ? silhouetteColorInactive : silhouetteColor
    shading
    zenith
    azimuth
    sunColor
    brightness = item?.brightness ?? 4.0
    objTexReplaceRules = "objTexReplaceRules{{0}}".subst(objTexReplace)
    objTexSetRules = "objTexSetRules{{0}}".subst(objTexSet)
    attachments = attachments.len() > 0 ? "attachments{{0}}".subst("".join(attachments)) : ""
    hideNodes = hideNodesTex.len() > 0 ? "hideNodes{{0}}".subst("".join(hideNodesTex)) : ""
    paintColor = paintColorParam
    blendFactor = item?.blendFactor ? $"blendfactor:r={item?.blendFactor}" : ""
    shaderColors
    silhouetteHasShadow = item?.silhouetteHasShadow ?? false
    silhouetteMinShadow = item?.silhouetteMinShadow ?? 1.0
    swapYZ = item?.swapYZ ?? true
    attachType = item?.attachType ?? "slot"
    forceRealTimeRenderIcon = needEnableRTRender ? "forceRenderEveryFrame:b=yes;" : ""
  })
  return getPicture(imageSource)
}

return iconWidget
