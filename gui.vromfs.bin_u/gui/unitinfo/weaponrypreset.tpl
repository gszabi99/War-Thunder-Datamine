weaponryPreset {
  size:t='<<tiersCount>>*<<slotScale>>*@modalInfoTierIconSize, <<slotScale>>*1@modalInfoTierIconSize'
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
          size:t='<<slotScale>>*@modalInfoTierIconSize, <<slotScale>>*@modalInfoTierIconSize'
          <<^isActive>>enable:t='no'<</isActive>>
          interactive:t='yes'
          shortcut-on-hover:t='yes'
          img {
            size:t='<<slotScale>>*@modalInfoTierIconSize, <<slotScale>>*@modalInfoTierIconSize'
            position:t='relative'
            background-image:t='<<#img>><<img>><</img>>'
            background-repeat:t='expand'
            background-svg-size:t='<<slotScale>>*@modalInfoTierIconSize, <<slotScale>>*@modalInfoTierIconSize'
          }
          <<#tierTooltipId>>
          tooltip-float:t='horizontal'
          <<#isTooltipByHold>>
          tooltipId:t='<<tierTooltipId>>'
          <</isTooltipByHold>>
          <<^isTooltipByHold>>
          tooltip:t='$tooltipObj'
          tooltipObj {
            tooltipId:t='<<tierTooltipId>>'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
            display:t='hide'
          }
          <</isTooltipByHold>>
          <</tierTooltipId>>
          focus_border {}
        }
      }
      <</tiersView>>
    }
    <</weaponryItem>>
  }
}