tdiv {
  id:t='strenght_<<sideName>>'
  width:t='pw'
  height:t='ph'
  <<#invert>>
    left:t='pw-w'; position:t='relative'
  <</invert>>
  flow:t='vertical'
  padding:t='1@framePadding'

  textareaNoTab {
    <<#invert>>
      left:t='pw-w'; position:t='relative'
    <</invert>>
    margin-bottom:t='1@framePadding'
    text:t='#worldwar/available_crafts'
    overlayTextColor:t='active'
  }

  tdiv {
    width:t='pw'
    flow:t='vertical'
    overflow-y:t='auto'
    <<^invert>>
      scroll-align:t='left'
    <</invert>>

    <<#unitString>>
    wwUnitActiveBlock {
      unit_name:t='<<id>>'

      <<#hasIndent>>
      padding-<<#invert>>right<</invert>><<^invert>>left<</invert>>:t='1@viewUnitsInGroupPadding'
      <</hasIndent>>

      <<#invert>>
      left:t='pw-w'; position:t='relative'

      textareaNoTab {
        text:t=' <<name>> '
      }
      <</invert>>

      <<#icon>>
      img {
        size:t='1@tableIcoSize, 1@tableIcoSize'
        background-svg-size:t='@tableIcoSize, @tableIcoSize'
        background-image:t='<<icon>>'
        background-repeat:t='aspect-ratio'
        shopItemType:t='<<shopItemType>>'
      }
      <</icon>>

      <<^invert>>
      textareaNoTab {
        text:t=' <<name>> '
      }
      <</invert>>

      <<#tooltipId>>
      title:t='$tooltipObj'
      tooltipObj {
        id:t='tooltip_obj'
        tooltipId:t='<<tooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }
      <</tooltipId>>
    }
    <</unitString>>
  }
}
