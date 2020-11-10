// "Purchase" button is blue and underlined
// because it leads to external resource.

td {
  cellType:t='left';

  textarea {
    id:t='amount';
    class:t='active';
    text-align:t='right';
    min-width:t='0.13@sf';
    text:t='<<amount>>';
    valign:t='center';
  }
}
td {
  activeText {
    id:t='discount';
    text:t='<<savingText>>';
    text-align:t='left';
    valign:t='center'
  }
}
td {
  textarea {
    id:t='cost';
    class:t='active';
    text-align:t='right';
    min-width:t='0.13@sf';
    text:t='<<cost>>';
    valign:t='center';
  }
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
