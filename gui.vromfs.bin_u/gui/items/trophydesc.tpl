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
<<#list>>
_newline{ size:t='0' }
tdiv {
  width:t='pw'
  max-width:t='p.p.w'
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

  prizeNest {
    width:t='pw'
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
    }
    <</icon>>
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
      <<^widthByParentParent>>
      width:t='fw'
      <</widthByParentParent>>
      <<#widthByParentParent>>
      max-width:t='p.p.p.p.w -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>> <<#buttonsCount>>-2@sIco*<<buttonsCount>><</buttonsCount>>'
      <</widthByParentParent>>
      pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
      font-bold:t='@fontSmall'
      text:t='<<title>>'
    }
    <</title>>

    <<#unitPlate>>
    <<#classIco>>
    classIconPlace {
      size:t='1@dIco, 1@dIco'
      pos:t='0, ph/2-h/2'
      position:t='relative'
      img {
        pos:t='pw/2-w/2, ph/2-h/2'; position:t='relative'
        background-image:t='<<classIco>>'
        background-repeat:t='aspect-ratio'
        shopItemType:t='<<shopItemType>>'
      }
    }
    <</classIco>>

    tdiv {
      <<^widthByParentParent>>
      width:t='fw'
      <</widthByParentParent>>
      <<#widthByParentParent>>
      max-width:t='p.p.p.p.w <<#classIco>>-1@dIco<</classIco>> -1@itemPadding <<#buttonsCount>>-2@sIco*<<buttonsCount>><</buttonsCount>>'
      <</widthByParentParent>>
      padding:t='-1@slot_interval, -1@slot_vert_pad'
      pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
      rankUpList {
        class:t='rankUpList'
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
    hoverButton {
      pos:t='0, ph/2-h/2'; position:t='relative'
      tooltip:t = '<<tooltip>>'
      on_click:t='<<funcName>>'
      no_text:t='yes'
      icon { background-image:t='<<image>>' }
      <<@actionParamsMarkup>>
    }
    <</buttons>>

    <<#tooltipId>>
    tooltipObj {
      id:t='tooltip_<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    title:t='$tooltipObj'
    <</tooltipId>>
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
    pos:t='0, -4@sf/@pf'; position:t='relative'
    padding-left:t='1@dIco <<#icon2>>+1@dIco<</icon2>> <<#previewImage>>+1@cIco<</previewImage>> +1@itemPadding'
    <</title>>
    <<#unitPlate>>
    pos:t='0, 2@sf/@pf'; position:t='relative'
    padding-left:t='<<#classIco>>1@dIco +<</classIco>> 1@itemPadding'
    <</unitPlate>>
    text:t='<<commentText>>'
    tinyFont:t='yes'
  }
  <</commentText>>
}
<</list>>
