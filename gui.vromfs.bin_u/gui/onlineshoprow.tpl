// "Purchase" button is blue and underlined
// because it leads to external resource.

td {
  max-width:t='0.65@onlineShopWidth'
  overflow:t='hidden'

  <<#unseenIcon>>
  unseenIcon {
    valign:t='center'
    noMargin:t='yes'
    value:t='<<unseenIcon>>'
  }
  <</unseenIcon>>

  textarea {
    id:t='amount';
    class:t='active';
    text-align:t='right';
    min-width:t='0.13@sf';
    text:t='<<amount>>';
    valign:t='center';
    auto-scroll:t='medium'
  }
}
<<#savingText>>
td {
  padding-left:t='@optPad'
  activeText {
    id:t='discount';
    text:t='<<savingText>>';
    text-align:t='left';
    valign:t='center'
  }
}
<</savingText>>
td {
  min-width:t='0.13@sf'
  <<^customCostMarkup>>
  textarea {
    id:t='cost'
    position:t='relative'
    pos:t='pw-w,0.5ph-0.5h'
    class:t='active'
    text:t='<<cost>>'
  }
  <</customCostMarkup>>
  <<#customCostMarkup>>
  tdiv {
    position:t='relative'
    pos:t='pw-w,0.5ph-0.5h'
    <<@customCostMarkup>>
  }
  <</customCostMarkup>>
}
td {
  id:t='<<rowName>>'

  Button_text {
    id:t='buttonBuy';
    pos:t='0, 50%ph-50%h';
    position:t='relative';
    noMargin:t='yes'
    showOn:t='hoverOrPcSelect'
    btnName:t='A';
    on_click:t='onRowBuy';

    <<^externalLink>>
    text:t='#mainmenu/btnBuy';
    visualStyle:t='purchase'
    buttonWink{}
    buttonGlance{}
    <</externalLink>>

    <<#externalLink>>
    text:t='';
    externalLink:t='yes';
    activeText {
      position:t='absolute';
      pos:t='0.5pw-0.5w, 0.5ph-0.5h - 2@sf/@pf_outdated';
      text:t='#mainmenu/btnBuy';
      underline {}
    }
    <</externalLink>>
    ButtonImg {}
  }
  discount {
    id:t='buy-discount'
    text:t='<<discount>>'
    pos:t='pw-65%w, -30%h'; position:t='absolute'
    rotation:t='-10'
  }
}
