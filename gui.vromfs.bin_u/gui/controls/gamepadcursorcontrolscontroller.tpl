tdiv {
  width:t='pw'
  height:t='0.511w'
  position:t='relative'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h'

  pattern { type:t='dark_diag_lines' }

  textAreaCentered {
    pos:t='0.5pw-0.5w, 25/642ph'; position:t='absolute'
    caption:t="yes"
    text:t='#gamepad_cursor_control_splash/header_text'
  }
}

img {
  position:t='absolute'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h+20/642ph'
  height:t='0.38*840/642ph'
  width:t='h*840/452'
  background-image:t='<<image>>'
}

tdiv {
  pos:t='0.5pw-0.5w, 0.5ph-0.5h+5/642ph'; position:t='absolute';
  height:t='ph+150/642ph'
  width:t='1.46h'

  // R_TRIGGER
  <<#rightTrigger>>
  tdiv {
    pos:t='<<contactPointX>>/1288pw-h, <<contactPointY>>/880ph-0.5h'
    size:t='173/1288pw, 1*@sf/@pf_outdated'
    position:t='absolute'
    background-color:t='@white'
  }
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/1288pw-0.5w, <<contactPointY>>/880ph-0.5h'
  }
  controlsHelpPs4Bubble {
    id:t='joy_r_trigger'
    pos:t='pw/2+250/1288pw, 297/880ph-0.5h'
    min-width:t='340/1288pw'
    text:t='#click'
  }
  <</rightTrigger>>


  // L_STICK
  <<#leftStick>>
  tdiv {
    pos:t='(<<contactPointX>> - 239)/1288pw, <<contactPointY>>/880ph-0.5h'
    size:t='239/1288pw, 1*@sf/@pf_outdated'
    position:t='absolute'
    background-color:t='@white'
  }
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/1288pw - 0.5w, <<contactPointY>>/880ph-0.5h'
  }
  controlsHelpPs4Bubble {
    id:t='joy_axis_l'
    pos:t='pw/2-270/1288pw-w, <<contactPointY>>/880ph-0.5h'
    min-width:t='370/1288pw'
    text:t='#move_cursor'
  }
  <</leftStick>>


  // R_STICK
  <<#rightStick>>
  tdiv {
    pos:t='<<contactPointX>>/1288pw-0.5w, <<contactPointY>>/880ph'
    size:t='1*@sf/@pf_outdated, (674 - <<contactPointY>>)/880ph'
    position:t='absolute'
    background-color:t='@white'
  }
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/1288pw-0.5w, <<contactPointY>>/880ph'
  }
  controlsHelpPs4Bubble {
    id:t='joy_axis_r'
    pos:t='pw/2 + 16/1288pw, 674/880ph-0.5h'
    min-width:t='470/1288pw'
    text:t='#scroll'
  }
  <</rightStick>>
}
