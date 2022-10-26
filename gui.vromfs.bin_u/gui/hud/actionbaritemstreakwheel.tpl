action_bar_item {
  id:t='<<id>>';
  pos:t='0, ph/2-h/2';
  position:t='relative';
  size:t='ph - 0.01@shHud, ph - 0.01@shHud';
  background-color:t='#77333333';
  selected:t='<<selected>>';
  active:t='<<active>>';
  enable:t='<<enable>>';
  css-hier-invalidate:t='yes';
  behaviour:t='button';
  behaviour:t='touchArea';

  action_item_content {
    css-hier-invalidate:t='yes';
    size:t='pw, ph';
    background-color:t='#55222222';
    selected_action_bg {
      size:t='pw, ph';
      position:t='absolute';
      pos:t='0, 0';
      background-image:t='#ui/gameuiskin#circle_gradient_white.png';
      background-color:t='#FFFFFF';
      display:t='hide';
    }
    <<#bullets>>
      <<bullets>>
    <</bullets>>
    <<^bullets>>
    img {
      id:t='action_icon'
      size:t='pw, ph';
      background-svg-size:t='pw, ph'
      background-image:t='<<icon>>';
    }
    <</bullets>>
    tdiv {
      id:t='cooldown'
      re-type:t='sector';
      sector-angle-1:t='<<cooldown>>';
      sector-angle-2:t='360';
      size:t='pw, ph';
      position:t='absolute';
      pos:t='0, 0';
      background-color:t='#cc0c111c';
    }
    textarea {
      id:t='amount_text';
      pos:t='pw - w, ph - h + 0.004@shHud';
      position:t='absolute';
      smallFont:t='yes';
      shadeStyle:t='outline33pct'
      text-align:t='right';
      text:t='<<amount>>';
    }
    <<#isXinput>>
      <<>gamepadShortcut>>
    <</isXinput>>
    <<^isXinput>>
      <<>textShortcut>>
    <</isXinput>>
  }
}

textareaNoTab {
  top:t='ph/2-h/2';
  position:t='relative';
  padding:t='0.01@shHud';
  killstreak:t='yes';
  text:t='<<name>>';
}
