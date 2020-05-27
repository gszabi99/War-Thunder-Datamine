<<#unitString>>
<<#isShow>>
tdiv {
  width:t='pw'
  <<#hasSpaceBetweenUnits>>
  height:t='1@unitStringHeight'
  <</hasSpaceBetweenUnits>>

  <<#isControlledByAI>>
  includeTextColor:t='disabled'
  <</isControlledByAI>>

  <<^reflect>>
    padding-left:t='3@dp'

    <<#isShow>>
      textareaNoTab {
        width:t='0.05@sf'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        <<#isShowTotalCount>>
          text:t='<<#count>><<count>><</count>>'
        <</isShowTotalCount>>
        <<^isShowTotalCount>>
          text:t='<<#activeCount>><<activeCount>><</activeCount>>'
        <</isShowTotalCount>>
      }

      <<#icon>>
      img {
        size:t='@tableIcoSize, @tableIcoSize'
        background-svg-size:t='@tableIcoSize, @tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        background-image:t='<<icon>>'
        background-repeat:t='aspect-ratio'
        shopItemType:t='<<shopItemType>>'
      }
      <</icon>>

      textareaNoTab {
        width:t='pw-0.05@sf-@tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        word-wrap:t='no'
        pare-text:t='yes'
        text:t=' <<#showType>><<unitType>><</showType>><<^showType>><<name>><</showType>> '
      }
    <</isShow>>
  <</reflect>>

  <<#hasPresetWeapon>>
  tdiv {
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    tooltip:t='<<?modification/category/secondaryWeapon>><<?ui/colon>>\n<<weapon>>'

    <<#presetCount>>
    textareaNoTab {
      text:t='('
    }
    <</presetCount>>

    <<#hasBomb>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_bomb' }
    <</hasBomb>>
    <<#hasRocket>>
      img { size:t='0.6@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_missile' }
    <</hasRocket>>
    <<#hasTorpedo>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_torpedo' }
    <</hasTorpedo>>
    <<#hasAdditionalGuns>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_pod' }
    <</hasAdditionalGuns>>

    <<#presetCount>>
    textareaNoTab {
      text:t='<<presetCount>>)'
    }
    <</presetCount>>
  }
  <</hasPresetWeapon>>

  <<#reflect>>
    pos:t='pw-w-3@dp, 0'
    position:t='relative'

    <<#isShow>>
      textareaNoTab {
        width:t='pw-0.05@sf-@tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        padding-right:t='3@dp'
        text-align:t='right'
        word-wrap:t='no'
        pare-text:t='yes'
        text:t=' <<#showType>><<unitType>><</showType>><<^showType>><<name>><</showType>> '
      }

      <<#icon>>
      img {
        size:t='@tableIcoSize, @tableIcoSize'
        background-svg-size:t='@tableIcoSize, @tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        background-image:t='<<icon>>'
        background-repeat:t='aspect-ratio'
        shopItemType:t='<<shopItemType>>'
      }
      <</icon>>

      textareaNoTab {
        width:t='0.05@sf'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        text-align:t='right'
        <<#isShowTotalCount>>
          text:t='<<#count>><<count>><</count>>'
        <</isShowTotalCount>>
        <<^isShowTotalCount>>
          text:t='<<#activeCount>><<activeCount>><</activeCount>>'
        <</isShowTotalCount>>
      }
    <</isShow>>
  <</reflect>>

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
<</isShow>>
<</unitString>>
