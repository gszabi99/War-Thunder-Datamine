actionBarItemDiv {
  margin:t='1@hudActionBarItemOffset, 0'
  padding:t='0.003@shHud'

  action_bar_item {
    id:t='<<id>>'
    size:t='pw, ph'
    position:t='absolute'
    background-color:t='#77333333'
    selected:t='<<selected>>'
    active:t='<<active>>'
    enable:t='<<enable>>'
    css-hier-invalidate:t='yes'

    behaviour:t='button'
    behaviour:t='touchArea'
    on_click:t='activateAction'

    action_item_content {
      css-hier-invalidate:t='yes'
      size:t='pw, ph'
      background-color:t='#55222222'
      selected_action_bg {
        size:t='pw, ph'
        position:t='absolute'
        pos:t='0, 0'
        background-image:t='#ui/gameuiskin#circle_gradient_white.png'
        background-color:t='#FFFFFF'
        display:t='hide'
      }
      <<#bullets>>
        <<bullets>>
      <</bullets>>
      <<^bullets>>
      img {
        id:t='action_icon'
        size:t='pw, ph'
        background-svg-size:t='pw, ph'
        background-image:t='<<icon>>'
      }
      <</bullets>>
      actionItemCooldown {
        id:t='cooldown'
        sector-angle-1:t='<<cooldown>>'
        inc-factor:t='<<cooldownIncFactor>>'
        background-color:t='#cc0c111c'
      }
      actionItemCooldown {
        id:t='progressCooldown'
        sector-angle-1:t='<<progressCooldown>>'
        inc-factor:t='<<progressCooldownIncFactor>>'
        background-color:t='#88080C12'
      }
      transpBlinkAnimation {
        id:t='availability'
        size:t='pw, ph'
        position:t='absolute'
        pos:t='0, 0'
        input-transparent:t='yes'
        background-image:t='#ui/gameuiskin#action_blink.png'
        background-color:t='#FFFFFF'
        color-factor:t='0'

        _transp-timer:t='1'
        transp-func:t='doubleBlink'
        transp-time:t='1000'
        _blink:t='no'
        blend-time:t='0'
      }
      textarea {
        id:t='amount_text'
        pos:t='pw - w, ph - h + 0.004@shHud'
        position:t='absolute'
        hudFont:t='small'
        shadeStyle:t='outline33pct'
        text-align:t='right'
        text:t='<<amount>>'
      }
      textarea {
        id:t='automatic_text'
        pos:t='pw -w -0.002@shHud, 0.004@shHud'
        position:t='absolute'
        hudFont:t='small'
        shadeStyle:t='outline33pct'
        text-align:t='right'
        text:t='#actionBar/action/automatic/abbr'
        <<^automatic>>display:t='hide'<</automatic>>
      }
      actionItemCooldown {
        id:t='blockedCooldown'
        sector-angle-1:t='<<blockedCooldown>>'
        inc-factor:t='<<blockedCooldownIncFactor>>'
        background-color:t='#99020202'
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

  tooltipLayer {
    id:t='tooltip_<<id>>'
    size:t='pw, ph'
    position:t='absolute'
    input-transparent:t='yes'

    <<#tooltipId>>
    title:t='$tooltipObj'
    tooltip-float:t='horizontal'
    tooltipObj {
      id:t='tooltip_<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    <<#tooltipDelayed>>
    tooltip-timeout:t='1000'
    <</tooltipDelayed>>
    <</tooltipId>>

    <<^tooltipId>>
    tooltip:t='<<tooltipText>>'
    <</tooltipId>>
  }
}
