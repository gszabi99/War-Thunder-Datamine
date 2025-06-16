from "%scripts/dagui_library.nut" import *



let collapsedTextIdxPID = dagui_propid_add_name_id("_collapsedIdx")
let collapsedTextBlocksAnim = [
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

function getCollapsedAnimSizeObj(scene, blockId) {
  return scene.findObject($"{blockId}_collapsed_size_obj")
}










function animSwitchCollapsedText(scene, blockId, text) {
  let animSizeObj = getCollapsedAnimSizeObj(scene, blockId)
  if (!checkObj(animSizeObj)) {
    assert(false, $"promoViewUtils: try to anim update text for not existing block: {blockId}")
    return
  }

  let prevShowIdx = animSizeObj.getIntProp(collapsedTextIdxPID, -1)
  let isInited = prevShowIdx >= 0
  let setIdx = isInited ? (prevShowIdx + 1) % collapsedTextBlocksAnim.len() : 0
  animSizeObj.setIntProp(collapsedTextIdxPID, setIdx)

  foreach (idx, animData in collapsedTextBlocksAnim) {
    let textObj = scene.findObject($"{blockId}{animData.blockEnding}")
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

function getVisibleCollapsedTextObj(scene, blockId) {
  local idx = 0
  let sizeObj = getCollapsedAnimSizeObj(scene, blockId)
  if (checkObj(sizeObj))
     idx = sizeObj.getIntProp(collapsedTextIdxPID, 0) % collapsedTextBlocksAnim.len()
  return scene.findObject("".concat(blockId, collapsedTextBlocksAnim[idx].blockEnding))
}

return {
  animSwitchCollapsedText,
  getVisibleCollapsedTextObj
}