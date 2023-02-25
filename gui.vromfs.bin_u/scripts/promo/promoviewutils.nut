//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
::g_promo_view_utils.animSwitchCollapsedText <- function animSwitchCollapsedText(scene, blockId, text) {
  let animSizeObj = this.getCollapsedAnimSizeObj(scene, blockId)
  if (!checkObj(animSizeObj)) {
    assert(false, "g_promo_view_utils: try to anim update text for not existing block: " + blockId)
    return
  }

  let prevShowIdx = animSizeObj.getIntProp(this.collapsedTextIdxPID, -1)
  let isInited = prevShowIdx >= 0
  let setIdx = isInited ? (prevShowIdx + 1) % this.collapsedTextBlocksAnim.len() : 0
  animSizeObj.setIntProp(this.collapsedTextIdxPID, setIdx)

  foreach (idx, animData in this.collapsedTextBlocksAnim) {
    let textObj = scene.findObject(blockId + animData.blockEnding)
    if (!checkObj(textObj))
      continue

    let isCurrent = idx == setIdx
    textObj.animation = isCurrent ? "show" : "hide"

    if (!isCurrent)
      continue

    textObj.setValue(text)
    textObj.getScene().applyPendingChanges(false)

    let width = textObj.getSize()[0]
    animSizeObj[animData.animSizeParamId] = width.tostring()
    animSizeObj.animation = animData.sizeObjAnim

    if (!isInited)
      animSizeObj.width = width.tostring()
  }
}

::g_promo_view_utils.getVisibleCollapsedTextObj <- function getVisibleCollapsedTextObj(scene, blockId) {
  local idx = 0
  let sizeObj = this.getCollapsedAnimSizeObj(scene, blockId)
  if (checkObj(sizeObj))
     idx = sizeObj.getIntProp(this.collapsedTextIdxPID, 0) % this.collapsedTextBlocksAnim.len()
  return scene.findObject(blockId + this.collapsedTextBlocksAnim[idx].blockEnding)
}

::g_promo_view_utils.getCollapsedAnimSizeObj <- function getCollapsedAnimSizeObj(scene, blockId) {
  return scene.findObject(blockId + "_collapsed_size_obj")
}