css-hier-invalidate:t="yes"
modIcon{
  id:t='icon'
  size:t='1@modItemHeight, 1@modItemHeight'
  position:t='relative'
  input-transparent:t="yes"
  css-hier-invalidate:t="yes"

  img{
    id:t='image'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    background-image:t='<<itemImg>>'

    <<@modUpgradeIcon>>
    upgradeImg {
      id:t='upgrade_img'
      upgradeStatus:t=''
    }
  }

  tdiv{
    id:t='bullets'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    css-hier-invalidate:t="yes"
    _iconBulletName:t='<<iconBulletName>>'
    <<#bulletImg>>
    include "gui/weaponry/bullets"
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
