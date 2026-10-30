from "%scripts/items/itemVisual.nut" import fillItemDescr
from "%scripts/dagui_library.nut" import *

function fillWarbondAwardDesc(descObj, handler, award) {
  let item = award.awardType.getDescItem(award.blk)
  if (!item)
    return false

  descObj.scrollToView(true)
  fillItemDescr(item, descObj, handler, true, true,
    { descModifyFunc = award.addAmountTextToDesc.bindenv(award) })
  return true
}

return freeze({ fillWarbondAwardDesc })