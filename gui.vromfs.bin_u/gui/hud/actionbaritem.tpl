action_bar_item {
  id:t='<<id>>';
  size:t='1@hudActionBarItemSize, 1@hudActionBarItemSize';
  margin:t='1@hudActionBarItemOffset, 0';
  padding:t='0.003@shHud';
  background-color:t='#77333333';
  selected:t='<<selected>>';
  active:t='<<active>>';
  enabled:t='<<enabled>>';
  css-hier-invalidate:t='yes';

  behaviour:t='button';
  behaviour:t='touchArea';
  on_click:t='activateAction';

  action_item_content {
    css-hier-invalidate:t='yes';
    size:t='pw, ph';
    background-color:t='#55222222';
    selected_action_bg {
      size:t='pw, ph';
      position:t='absolute';
      pos:t='0, 0';
      background-image:t='#ui/gameuiskin#circle_gradient_white';
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
      background-image:t='<<icon>>';
      tooltip:t='<<tooltipText>>'
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
    transpBlinkAnimation {
      id:t='availability';
      size:t='pw, ph';
      position:t='absolute';
      pos:t='0, 0';
      input-transparent:t='yes';
      background-image:t='#ui/gameuiskin#action_blink';
      background-color:t='#FFFFFF';
      color-factor:t='0';

      _transp-timer:t='1';
      transp-func:t='doubleBlink';
      transp-time:t='1000';
      _blink:t='no';
      blend-time:t='0';
    }
    textarea {
      id:t='amount_text';
      pos:t='pw - w, ph - h + 0.004@shHud';
      position:t='absolute';
      hudFont:t='small';
      shadeStyle:t='outline33pct'
      text-align:t='right';
      text:t='<<amount>>';
    }
    textarea {
      id:t='automatic_text';
      pos:t='pw -w -0.002@shHud, 0.004@shHud';
      position:t='absolute';
      hudFont:t='small';
      shadeStyle:t='outline33pct'
      text-align:t='right';
      text:t='#actionBar/action/automatic/abbr';
      display:t='hide'
    }
    tdiv {
      id:t='BlockedCooldown'
      re-type:t='sector';
      sector-angle-1:t='360';
      sector-angle-2:t='360';
      size:t='pw, ph';
      position:t='absolute';
      pos:t='0, 0';
      background-color:t='#99020202';
    }
    <<#showShortcut>>
    <<#isXinput>>
      <<>gamepadShortcut>>
    <</isXinput>>
    <<^isXinput>>
      <<>textShortcut>>
    <</isXinput>>
    <</showShortcut>>
  }
}
