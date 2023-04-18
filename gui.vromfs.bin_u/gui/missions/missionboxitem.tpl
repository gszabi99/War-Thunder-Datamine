<<itemTag>><<^itemTag>>mission_item_unlocked<</itemTag>> {
  id:t='<<id>>'
  css-hier-invalidate:t='yes'

  <<#noMargin>>
  noMargin:t='yes'
  <</noMargin>>

  <<#isHidden>>
  display:t='hide'
  enable:t='no'
  <</isHidden>>

  <<#tooltip>>
  tooltip:t='<<tooltip>>'
  <</tooltip>>

  <<#isSelected>>
  selected:t='yes'
  <</isSelected>>

  <<#isCollapsable>>
  collapsed:t='no'
  collapsing:t='no'
  collapse_header:t='yes'
  <</isCollapsable>>

  <<^isCollapsable>>
  <<#isHeader>>
  collapsed:t='no'
  collapsing:t='no'
  collapse_header:t='no'
  <</isHeader>>
  <</isCollapsable>>

  <<#itemClass>>
  class:t='<<itemClass>>'
  <</itemClass>>

  <<#isNeedOnHover>>
  on_hover:t='onItemHover'
  on_unhover:t='onItemHover'
  <</isNeedOnHover>>

  <<#itemPrefixText>>
  hasItemPrefixText:t='yes'
  mission_item_text {
    id:t='mission_item_prefix_text_<<id>>'
    pos:t='0, 50%(ph-h)'
    text:t='<<itemPrefixText>>'
  }
  <</itemPrefixText>>

  <<imgTag>><<^imgTag>>img<</imgTag>> {
    id:t='medal_icon'
    medalIcon:t='yes'
    background-image:t='<<itemIcon>>'
    <<#iconColor>>
      style:t='background-color:<<iconColor>>'
    <</iconColor>>
    <<#isLastPlayedIcon>>
      isLastPlayedIcon:t='yes'
    <</isLastPlayedIcon>>
  }

  <<#checkBoxActionName>>
  CheckBox {
    id:t='checkbox_<<id>>'
    pos:t='@missionBoxImageOffsetX - 50%w, 50%ph - 50%h'
    position:t='absolute'
    class:t='empty'
    value:t='<<isChosen>>'
    on_change_value:t='<<checkBoxActionName>>'
    CheckBoxImg{}
  }
  <</checkBoxActionName>>

  <<#hasWaitAnim>>
  animated_wait_icon {
    id:t = 'wait_icon_<<id>>'
    class:t='missionBox'
    background-rotation:t = '0'
  }
  <</hasWaitAnim>>

  missionDiv {
    css-hier-invalidate:t='yes'

    <<#unseenIcon>>
    unseenIcon {
      <<#unseenIconId>>id:t='<<unseenIconId>>'<</unseenIconId>>
      value:t='<<unseenIcon>>'
    }
    <</unseenIcon>>

    tdiv {
      id:t= 'additional_desc'
      <<@additionalDescription>>
    }

    mission_item_text {
      id:t = 'txt_<<id>>'
      top:t='50%ph-50%h'
      text:t = '<<itemText>>'
    }
  }

  <<#isSpecial>>
  img { medalIcon:t='dlc' }
  <</isSpecial>>

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    id:t='btn_<<id>>'
    css-hier-invalidate:t='yes'
    square:t='yes'
    on_click:t='onCollapse'
    activeText{}
  }
  <</isCollapsable>>

  <<#discountText>>
  discount {
    id:t='mis-discount'
    text:t='<<discountText>>'
  }
  <</discountText>>

  <<#tooltipObjId>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<tooltipObjId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</tooltipObjId>>

  ButtonImg { btnName:t='A' }
}