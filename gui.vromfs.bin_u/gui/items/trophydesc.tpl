<<#header>>
_newline{ size:t='0' }
textareaNoTab {
  <<#timerId>>
  id:t='<<timerId>>'
  behavior:t='Timer'
  <</timerId>>

  <<^widthByParentParent>>
  width:t='pw'
  <</widthByParentParent>>
  <<#widthByParentParent>>
  max-width:t='p.p.w'
  <</widthByParentParent>>

  <<#hasHeaderPadding>>
    padding:t='1@itemPadding, 0'
  <</hasHeaderPadding>>
  margin-bottom:t='1@itemPadding'
  font-bold:t='@fontMedium'
  <<#headerFont>>
  <<@headerFont>>:t='yes'
  <</headerFont>>
  <<#isCentered>>
    position:t='relative'
    left:t='(pw-w)/2'
  <</isCentered>>
  text:t='<<header>>'
}
<</header>>

<<#isCollapsable>>
tdiv {
  id:t='item_info_collapsable_prizes'
  width:t='pw'
  max-width:t='p.p.w'
<</isCollapsable>>

<<#list>>
<<^hasHorizontalFlow>>
_newline{ size:t='0' }
<</hasHorizontalFlow>>
tdiv {
  <<^hasHorizontalFlow>>
  width:t='pw'
  <<^isCollapsable>>
  max-width:t='p.p.w'
  <</isCollapsable>>
  <</hasHorizontalFlow>>
  flow:t='vertical'
  total-input-transparent:t='yes'
  <<#tooltip>>
  tooltip:t='<<tooltip>>'
  <</tooltip>>
  <<#isLocked>>
  includeTextColor:t='locked'
  <</isLocked>>
  <<#isCentered>>
  position:t='relative'
  left:t='(pw-w)/2'
  <</isCentered>>
  <<#isHighlightedLine>>
  background-color:t='@evenTrColor'
  <</isHighlightedLine>>

  <<#isCollapsable>>
  isCategory:t=<<#isCategory>>'yes'<</isCategory>><<^isCategory>>'no'<</isCategory>>
  <<#isCategory>>
  categoryId:t=<<categoryId>>
  css-hier-invalidate:t='yes'
  collapsed:t='yes'
  behaviour:t='button'
  on_click:t='<<onCategoryClick>>'
  focusBtnName:t='A'
  focus_border {}
  <</isCategory>>
  <<^isCategory>>
  display:t='hide'
  enable:t='no'
  <</isCategory>>
  <</isCollapsable>>

  <<#isTooltipByHold>>
  <<#tooltipId>>
  tooltipId:t='<<tooltipId>>'
  behavior = 'button'
  on_pushed = '::gcb.delayedTooltipPush'
  on_hold_start = '::gcb.delayedTooltipHoldStart'
  on_hold_stop = '::gcb.delayedTooltipHoldStop'
  navigatorShortcuts = 'SpaceA'
  not-input-transparent:t='yes'
  <</tooltipId>>
  <</isTooltipByHold>>

  prizeNest {
    <<^hasHorizontalFlow>>
    width:t='pw'
    <</hasHorizontalFlow>>

    <<#isCategory>>
    css-hier-invalidate:t='yes'
    fullSizeCollapseBtn {
      css-hier-invalidate:t='yes'
      square:t='yes'
      activeText{}
    }
    <</isCategory>>

    <<#title>>
    <<#icon>>
    img {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='<<icon>>'
      background-repeat:t='aspect-ratio'
      <<#isLocked>>
      isLocked:t='yes'
      <</isLocked>>
      margin-right:t='1@itemPadding'
    }
    <</icon>>
    <<#classIco>>
    img {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='<<classIco>>'
      <<#isLocked>>
      isLocked:t='yes'
      <</isLocked>>
      shopItemType:t='<<shopItemType>>'
      margin-right:t='1@itemPadding'
    }
    <</classIco>>
    <<#icon2>>
    img {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='<<icon2>>'
      <<#isLocked>>
      isLocked:t='yes'
      <</isLocked>>
    }
    <</icon2>>
    <<@previewImage>>

    textareaNoTab {
      <<^hasHorizontalFlow>>
      <<^widthByParentParent>>
      width:t='fw'
      <</widthByParentParent>>
      <<#widthByParentParent>>
      max-width:t='p.p.p.p.w -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>> <<#buttonsCount>>-2@sIco*<<buttonsCount>><</buttonsCount>>'
      <</widthByParentParent>>
      <</hasHorizontalFlow>>
      pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
      interactive:t='yes'
      font-bold:t='@fontSmall'
      text:t='<<title>>'
    }
    <</title>>

    <<#unitPlate>>
    iconsPlace {
      flow:t='vertical'
      height:t='ph'
      valign:t='center'
      <<#classIco>>
      classIconPlace {
        size:t='1@dIco, 1@dIco'
        position:t='relative'
        img {
          pos:t='pw/2-w/2, ph/2-h/2'
          position:t='relative'
          background-image:t='<<classIco>>'
          background-repeat:t='aspect-ratio'
          shopItemType:t='<<shopItemType>>'
        }
      }
      <</classIco>>
      <<#countryIco>>
      countryIconPlace {
        size:t='1@dIco, 1@dIco'
        position:t='relative'
        img {
          pos:t='pw/2-w/2, ph/2-h/2'
          position:t='relative'
          background-image:t='<<countryIco>>'
          background-repeat:t='aspect-ratio'
        }
      }
      <</countryIco>>
    }
    tdiv {
      <<^widthByParentParent>>
      width:t='fw'
      <</widthByParentParent>>
      <<#widthByParentParent>>
      max-width:t='p.p.p.p.w <<#countryIco>>-1@dIco<</countryIco>> -1@itemPadding <<#buttonsCount>>-2@sIco*<<buttonsCount>><</buttonsCount>>'
      <</widthByParentParent>>
      padding:t='-1@slot_interval, -1@slot_vert_pad'
      pos:t='1@itemPadding, ph/2-h/2'
      position:t='relative'
      rankUpList {
        holdTooltipChildren:t='yes'
        <<@unitPlate>>
      }
    }
    <</unitPlate>>

    <<#chanceIcon>>
    chanceIconPlace {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      chanceIcon {
        pos:t='pw/2-w/2, ph/2-h/2'
        position:t='absolute'
        background-image:t='<<chanceIcon>>'
        background-color:t='@gray'
        tooltip:t='<<chanceTooltip>>'
      }
    }
    <</chanceIcon>>

    <<#buttons>>
    <<^emptyButton>>
    hoverButton {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      tooltip:t = '<<tooltip>>'
      on_click:t='<<funcName>>'
      no_text:t='yes'
      icon { background-image:t='<<image>>' }
      <<@actionParamsMarkup>>
    }
    <</emptyButton>>
    <<#emptyButton>>    /*To align block buttons size for all prize*/
    emptyButtonBlock {}
    <</emptyButton>>
    <</buttons>>

    <<^isTooltipByHold>>
    <<#tooltipId>>
    tooltipObj {
      id:t='tooltip_<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    title:t='$tooltipObj'
    tooltip-float:t='horizontal'
    <</tooltipId>>
    <</isTooltipByHold>>
  }
  <<#commentText>>
  _newline{ size:t='0' }
  textareaNoTab {
    <<^widthByParentParent>>
    width:t='pw'
    <</widthByParentParent>>
    <<#widthByParentParent>>
    max-width:t='p.p.w'
    <</widthByParentParent>>
    <<#title>>
    pos:t='0, -4@sf/@pf'
    position:t='relative'
    padding-left:t='1@itemPadding <<#icon>>+1@dIco<</icon>> <<#icon2>>+1@dIco<</icon2>> <<#previewImage>>+1@cIco<</previewImage>>'
    <</title>>
    <<#unitPlate>>
    pos:t='0, 2@sf/@pf'
    position:t='relative'
    padding-left:t='<<#classIco>>1@dIco +<</classIco>> 1@itemPadding'
    <</unitPlate>>
    text:t='<<commentText>>'
    tinyFont:t='yes'
  }
  <</commentText>>
}
<</list>>

<<#isCollapsable>>
}
<</isCollapsable>>