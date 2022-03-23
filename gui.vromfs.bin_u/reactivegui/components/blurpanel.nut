let { isInVr } = require("%rGui/style/screenState.nut")
let colors = require("%rGui/style/colors.nut")

let blurPanel = @() {
  watch = isInVr
  rendObj = !isInVr.value ? ROBJ_WORLD_BLUR_PANEL : null
  size = flex()
  children = {
    rendObj = ROBJ_SOLID
    size = flex()
    color = !isInVr.value ? colors.menu.blurBgrColor : colors.transparent
  }
}

return blurPanel
