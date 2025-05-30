from "%rGui/globals/ui_library.nut" import *
let {getTexReplaceString, getTexSetString} = require("%rGui/components/itemTexReplace.nut")

let RENDER_PARAMS = @"ui/gameuiskin#render{
  itemName:t={itemName};animchar:t={animchar};autocrop:b=false;
  yaw:r={yaw};pitch:r={pitch};roll:r={roll};
  w:i={width};h:i={height};offset:p2={offset_x},{offset_y};scale:r={scale};
  outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};
  {zenith}{azimuth}
  {attachments}
  {hideNodes}
  {objTexReplaceRules}
  {objTexSetRules}
  {paintColor}
  {blendFactor}
  {shaderColors}
}.render"

let iconWidgetDef = {
  width = hdpx(64)
  height = hdpx(64)
  outline = [0,0,0,0]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  shading = "full" 
  silhouette = [192,192,192,200]
}

let cachedPictures = {}

function getPicture(source) {
  local pic = cachedPictures?[source]
  if (pic)
    return pic
  pic = Picture(source)
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

function iconWidget(item, params = iconWidgetDef, iconAttachments = null) {
  let { children = null } = params
  let { iconName = "", itemName = "" } = item
  if (iconName == "") {
    return {
      children
    }
  }

  let outlineColor = ",".join(params?.outline ?? iconWidgetDef.outline)
  let outlineColorInactive = ",".join(params?.outlineInactive ?? iconWidgetDef.outline)
  let {
    width = iconWidgetDef.width,
    height = iconWidgetDef.height,
    vplace = iconWidgetDef.vplace,
    hplace = iconWidgetDef.hplace,
    shading = iconWidgetDef.shading
  } = params
  let silhouetteColor = ",".join(params?.silhouette ?? iconWidgetDef.silhouette)
  let silhouetteColorInactive = ",".join(params?.silhouetteInactive ?? iconWidgetDef.silhouette)
  let imageHeight = height.tointeger()
  let imageWidth = width.tointeger()
  let zenith = item?.lightZenith ? $"zenith:r={item.lightZenith};" : ""
  let azimuth = item?.lightAzimuth ? $"azimuth:r={item.lightAzimuth};" : ""
  let objTexReplace = getTexReplaceString(item)
  let objTexSet = getTexSetString(item)
  let shaderColors = getShaderColorsString(item)

  let haveActiveAttachments = iconAttachments != null
  let attachments = []
  foreach (i, attachment in iconAttachments ?? []) {
    attachments.append($"a{i}\{animchar:t={attachment?.animchar};slot:t={attachment?.slot};scale:r={attachment?.scale ?? 1.0};outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};\}")
  }
  foreach (decorator in item?.decorators ?? []) {
    attachments.append($"a\{relativeTm:m={getTMatrixString(decorator?.relativeTm)};animchar:t={decorator?.animchar};parentNode:t={decorator?.nodeName};shading:t=same;attachType:t=node;swapYZ:b={decorator?.swapYZ ?? true};\}")
  }

  let hideNodes = (item?.hideNodes ?? []).map(@(node) $"node:t={node};")
  let color = item?.paintColor
  let paintColorParam = color ? $"paintColor:p4={color.x}, {color.y}, {color.z}, {color.w}" : ""

  
  let headgenReplace = item?.headgenTex0 && item?.headgenTex1 ?
    @"from:t=head_european_01_tex_d*;to:t={tex0}_d*;
    from:t=head_european_02_tex_d*;to:t={tex1}_d*;
    from:t=head_european_01_tex_n*;to:t={tex0}_n*;
    from:t=head_european_02_tex_n*;to:t={tex1}_n*;".subst({tex0 = item?.headgenTex0, tex1 = item?.headgenTex1}) : ""

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
    outlineColor = haveActiveAttachments ? outlineColorInactive : outlineColor
    silhouetteColor = haveActiveAttachments ? silhouetteColorInactive : silhouetteColor
    shading
    zenith
    azimuth
    objTexReplaceRules = "objTexReplaceRules{{0} r1{{1}}}".subst(objTexReplace, headgenReplace)
    objTexSetRules = "objTexSetRules{{0}}".subst(objTexSet)
    attachments = attachments.len() > 0 ? "attachments{{0}}".subst("".join(attachments)) : ""
    hideNodes = hideNodes.len() > 0 ? "hideNodes{{0}}".subst("".join(hideNodes)) : ""
    paintColor = paintColorParam
    blendFactor = item?.blendFactor ? $"blendfactor:r={item?.blendFactor}" : ""
    shaderColors
  })
  let image = getPicture(imageSource)

  return {
    rendObj = ROBJ_IMAGE
    image = image
    key = image
    vplace = vplace
    hplace = hplace
    children = children
    size = [width,height]
    keepAspect = KEEP_ASPECT_FIT
  }.__update(params)
}

return iconWidget
