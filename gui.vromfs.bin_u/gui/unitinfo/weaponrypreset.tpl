weaponryPreset {
  size:t='13*@modalInfoTierIconSize, 1@modalInfoTierIconSize'
  halign:t='center'
  tdiv {
    width:t='pw'
    position:t='absolute'
    <<#weaponryItem>>
    tdiv {
      flow:t='horizontal'
      css-hier-invalidate:t='yes'
      total-input-transparent:t='yes'
      isContainer:t='yes'
      skip-navigation:t='yes'
      shortcut-on-hover:t='yes'
      <<#tiersView>>
      tooltipLink {
        weaponryTier{
          size:t='@modalInfoTierIconSize, @modalInfoTierIconSize'
          <<^isActive>>enable:t='no'<</isActive>>
          interactive:t='yes'
          shortcut-on-hover:t='yes'
          img {
            size:t='@modalInfoTierIconSize, @modalInfoTierIconSize'
            position:t='relative'
            background-image:t='<<#img>><<img>><</img>>'
            background-repeat:t='expand'
            background-svg-size:t='@modalInfoTierIconSize, @modalInfoTierIconSize'
          }
          <<#tierTooltipId>>
          title:t='$tooltipObj'
          tooltip-float:t='horizontal'
          tooltipId:t='<<tierTooltipId>>'
          tooltipObj {
            tooltipId:t='<<tierTooltipId>>'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
            display:t='hide'
          }
          <</tierTooltipId>>
          focus_border {}
        }
      }
      <</tiersView>>
    }
    <</weaponryItem>>
  }
}