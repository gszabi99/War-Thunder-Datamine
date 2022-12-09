<<#fixedPresetView>>
fixedPreset {
  size:t='pw, 1@damageControlIconSize'
  margin-top:t='1@unlocksListboxItemInterval'
  <<#hasBottomGap>>
  margin-bottom:t='4@blockInterval'
  <</hasBottomGap>>
  css-hier-invalidate:t='yes'
  flow:t='horizontal'
  fixedPresetHeader {
    css-hier-invalidate:t='yes'
    size:t='5@damageControlIconSize, ph'
    textareaNoTab {
      position:t='relative'
      pos:t='1@modPadSize, 0.5ph-0.5h'
      text-align:t='left'
      text:t='<<presetName>>'
      smallFont:t='no'
      css-hier-invalidate:t='yes'
    }
  }
  actionsNest {
    size:t='pw - 5@damageControlIconSize, ph'
    <<#actionsView>>
    actionItem{
      size:t='1@damageControlIconSize, 1@damageControlIconSize'
      margin-left:t='1.5@damageControlIconSize'
      img {
        size:t='pw, ph'
        position:t='relative'
        background-image:t='<<#img>><<img>><</img>>'
        background-repeat:t='expand'
        background-svg-size:t='@damageControlIconSize, @damageControlIconSize'
      }
      <<^lastAction>>
      img {
        margin-left:t='0.375@damageControlIconSize'
        size:t='0.5@damageControlIconSize, @damageControlIconSize'
        background-color:t='#11ffffff'
        background-image:t='#ui/gameuiskin#item_upgrade'
        rotation:t='90'
        color-factor:t='64'
      }
      <</lastAction>>
    }
    <</actionsView>>
  }
}
<</fixedPresetView>>