css-hier-invalidate:t="yes"
modIcon{
  id:t='icon'
  <<^isFullItemSizedIcon>>
    size:t='1@modItemHeight, 1@modItemHeight'
  <</isFullItemSizedIcon>>
  <<#isFullItemSizedIcon>>
    size:t='pw, ph'
  <</isFullItemSizedIcon>>
  position:t='relative'
  <<#hideNameTextAndCenterIcon>>
    pos:t='50%pw-50%w, 50%ph-50%h'
  <</hideNameTextAndCenterIcon>>
  input-transparent:t="yes"
  css-hier-invalidate:t="yes"

  <<^isFullItemSizedIcon>>
  img{
    id:t='image'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    background-image:t='<<itemImg>>'
    background-svg-size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'

    <<@modUpgradeIcon>>
    upgradeImg {
      id:t='upgrade_img'
      upgradeStatus:t=''
    }
  }
  <</isFullItemSizedIcon>>

  <<#isFullItemSizedIcon>>
    <<#presetCompositionIcon>>
      div {
        size:t='pw, ph'
        id:t='presetCompositionIcon'
        include "%gui/weaponry/presetCompositionComplexIcon.tpl"
      }
    <</presetCompositionIcon>>

    <<#isCreateEmptyPresetBtnShown>>
      div {
        position:t='relative'
        pos:t='50%pw-50%w, 50%ph-50%h'

        img {
          position:t='relative'
          top:t='50%ph-50%h'
          background-image:t='#ui/gameuiskin#btn_inc.svg'
          size:t='0.75@newWidgetIconHeight, 0.75@newWidgetIconHeight'
          background-svg-size:t='0.75@newWidgetIconHeight, 0.75@newWidgetIconHeight'
          margin-right:t='2@weaponIconPadding'
        }

        textareaNoTab {
          position:t='relative'
          top:t='50%ph-50%h'
          smallFont:t='yes'
          text:t='#mainmenu/btnCreatePreset'
        }
      }
    <</isCreateEmptyPresetBtnShown>>
  <</isFullItemSizedIcon>>

  tdiv{
    id:t='bullets'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    css-hier-invalidate:t="yes"
    _iconBulletName:t='<<iconBulletName>>'
    <<#bulletImg>>
    include "%gui/weaponry/bullets.tpl"
    <</bulletImg>>
  }
  warningIcon {
    id:t='warning_icon'
    <<#hideWarningIcon>>display:t='hide'<</hideWarningIcon>>
  }
  box {
    pos:t='ph-w-1@weaponIconPadding, ph-h-1@weaponIconPadding'
    position:t='absolute'
    max-width:t='pw'
    overflow:t='hidden'
    text {
      id:t='amount'
      smallFont:t='yes'
      text:t='<<amountText>>'
      overlayTextColor:t='<<amountTextColor>>'
      auto-scroll:t='medium'
    }
  }
}
