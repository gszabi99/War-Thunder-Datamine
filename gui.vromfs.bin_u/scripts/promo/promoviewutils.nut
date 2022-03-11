//functions to specific update promoBlock parameters generated via promoBlock.tpl

::g_promo_view_utils <- {

  collapsedTextIdxPID = ::dagui_propid.add_name_id("_collapsedIdx")
  collapsedTextBlocksAnim = [
    {
      blockEnding = "_collapsed_text"
      animSizeParamId = "width-base"
      sizeObjAnim = "hide"
    }
    {
      blockEnding = "_collapsed_text2"
      animSizeParamId = "width-end"
      sizeObjAnim = "show"
    }
  ]
}

/*
  work only with blocks which have needCollapsedTextAnimSwitch flag
  return index (int) of new animated visible block.

  scene - dagui obj where to search promoblocks
  blockId - block id to switch texts
  text - text to set
  prevShowIdx - previous text index returned by this function. if never called before, than -1
*/
g_promo_view_utils.animSwitchCollapsedText <- function animSwitchCollapsedText(scene, blockId, text)
{
  local animSizeObj = getCollapsedAnimSizeObj(scene, blockId)
  if (!::checkObj(animSizeObj))
  {
    ::dagor.assertf(false, "g_promo_view_utils: try to anim update text for not existing block: " + blockId)
    return
  }

  local prevShowIdx = animSizeObj.getIntProp(collapsedTextIdxPID, -1)
  local isInited = prevShowIdx >= 0
  local setIdx = isInited ? (prevShowIdx + 1) % collapsedTextBlocksAnim.len() : 0
  animSizeObj.setIntProp(collapsedTextIdxPID, setIdx)

  foreach(idx, animData in collapsedTextBlocksAnim)
  {
    local textObj = scene.findObject(blockId + animData.blockEnding)
    if (!::checkObj(textObj))
      continue

    local isCurrent = idx == setIdx
    textObj.animation = isCurrent ? "show" : "hide"

    if (!isCurrent)
      continue

    textObj.setValue(text)
    textObj.getScene().applyPendingChanges(false)

    local width = textObj.getSize()[0]
    animSizeObj[animData.animSizeParamId] = width.tostring()
    animSizeObj.animation = animData.sizeObjAnim

    if (!isInited)
      animSizeObj.width = width.tostring()
  }
}

g_promo_view_utils.getVisibleCollapsedTextObj <- function getVisibleCollapsedTextObj(scene, blockId)
{
  local idx = 0
  local sizeObj = getCollapsedAnimSizeObj(scene, blockId)
  if (::checkObj(sizeObj))
     idx = sizeObj.getIntProp(collapsedTextIdxPID, 0) % collapsedTextBlocksAnim.len()
  return scene.findObject(blockId + collapsedTextBlocksAnim[idx].blockEnding)
}

g_promo_view_utils.getCollapsedAnimSizeObj <- function getCollapsedAnimSizeObj(scene, blockId)
{
  return scene.findObject(blockId + "_collapsed_size_obj")
}