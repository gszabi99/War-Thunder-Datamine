from "%scripts/dagui_library.nut" import *
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { getDiscount } = require("%scripts/discounts/discountsState.nut")
let { topMenuRightSideSections } = require("%scripts/mainmenu/topMenuSections.nut")

let getDiscountIconId = @(name) $"{name}_discount"

function updateDiscountNotifications(scene = null) {
  foreach (name in ["topmenu_research", "changeExp"]) {
    let id = getDiscountIconId(name)
    let obj = checkObj(scene) ? scene.findObject(id) : get_cur_gui_scene()[id]
    if (!(obj?.isValid() ?? false))
      continue

    let discount = getDiscount(name)
    let hasDiscount = name == "topmenu_research"
      ? discount && !(promoteUnits.value.findvalue(@(d) d.isActive) != null)
      : discount
    obj.show(hasDiscount)
  }

  let section = topMenuRightSideSections.getSectionByName("shop")
  let sectionId = section.getTopMenuButtonDivId()
  let shopObj = checkObj(scene) ? scene.findObject(sectionId) : get_cur_gui_scene()[sectionId]
  if (!checkObj(shopObj))
    return

  let stObj = shopObj.findObject(section.getTopMenuDiscountId())
  if (!checkObj(stObj))
    return

  local haveAnyDiscount = false
  foreach (column in section.buttons) {
    foreach (button in column) {
      if (!button.needDiscountIcon)
        continue

      let id = getDiscountIconId(button.id)
      let dObj = shopObj.findObject(id)
      if (!checkObj(dObj))
        continue

      let discountStatus = getDiscount(button.id)
      haveAnyDiscount = haveAnyDiscount || discountStatus
      dObj.show(discountStatus)
    }
  }

  stObj.show(haveAnyDiscount)
}

return updateDiscountNotifications
