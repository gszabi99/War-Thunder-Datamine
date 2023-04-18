<<#level>>
warbondShopLevel {
  id:t='<<id>>'
  left:t='<<posX>>'
  tooltip:t='<<tooltip>>'
  status = <<status>>
  background-image:t='<<levelIcon>>'
  hasOverlayIcon:t='<<#hasOverlayIcon>>yes<</hasOverlayIcon>><<^hasOverlayIcon>>no<</hasOverlayIcon>>'
  foreground-image:t='<<levelIconOverlay>>'
  total-input-transparent:t='yes'

  textareaNoTab {
    id:t='<<id>>_text'
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    hideEmptyText:t='yes'
    tinyFont:t='yes'
    width:t='pw'
    text-align:t='center'
    text:t='<<text>>'
  }
}
<</level>>