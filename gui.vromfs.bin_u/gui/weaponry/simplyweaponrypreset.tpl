simplyWeaponryPreset {
  padding:t='0, 1@blockInterval'
  height:t='@tierIconSize'
  tdiv {
    width:t='pw'
    overflow:t='hidden'
    position:t='absolute'
    tdiv {
      flow:t='horizontal'
      css-hier-invalidate:t='yes'
      total-input-transparent:t='yes'
      <<#tiersView>>
      weaponryTier{
        size:t='@tierIconSize, @tierIconSize'
        <<^isActive>>enable:t='no'<</isActive>>
        img {
          size:t='@tierIconSize, @tierIconSize'
          position:t='relative'
          background-image:t='<<#img>><<img>><</img>>'
          background-repeat:t='expand'
          background-svg-size:t='@tierIconSize, @tierIconSize'
        }
        <<#tierTooltipId>>
        title:t='$tooltipObj'
        tooltip-float:t='horizontal'
        tooltipObj {
          id:t='tierTooltip'
          tooltipId:t='<<tierTooltipId>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }
        <</tierTooltipId>>
      }
      <</tiersView>>
    }
  }
}
