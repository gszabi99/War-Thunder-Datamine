tdiv {
  width:t='pw'
  height:t='0.511w'
  position:t='relative'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h'

  pattern { type:t='dark_diag_lines' }

  textAreaCentered {
    pos:t='0.5pw-0.5w, 20/642ph'; position:t='absolute'
    titleFont:t="yes"
    max-width:t='pw'
    text:t='#gamepad_cursor_control_splash/header_text'
  }
}

img {
  id:t='gamepad_image'
  position:t='absolute'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h-50/642ph'
  height:t='0.38*840/642ph'
  width:t='h*840/452'
  background-image:t='<<image>>'

  tdiv{
    id:t='lines_block'
    size:t='sw, sh'
    position:t='root'
  }

  // DIRPAD
  <<#dirpad>>
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/840pw-0.5w, <<contactPointY>>/452ph-0.5h'
    shadow {}
    tdiv { id:t='dot_dirpad'; size:t='@dp, @dp'; pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute' }
  }
  controlsHelpPs4Bubble {
    id:t='bubble_dirpad'
    <<^isSwapDirpadAndLStickBubblesPos>>pos:t='-20/840pw-w, <<contactPointY>>/452ph-0.5h'<</isSwapDirpadAndLStickBubblesPos>>
    <<#isSwapDirpadAndLStickBubblesPos>>pos:t='pw/2 -20/840pw -w, ph +30/452ph'<</isSwapDirpadAndLStickBubblesPos>>
    width:t='400/840pw'
    class:t='noIcon'
    text:t='#gamepad_cursor_control_splash/navigation_by_ui_objects'
  }
  <</dirpad>>

  // L_STICK
  <<#leftStick>>
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/840pw-0.5w, <<contactPointY>>/452ph-0.5h'
    shadow {}
    tdiv { id:t='dot_lstick'; size:t='@dp, @dp'; pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute' }
  }
  controlsHelpPs4Bubble {
    id:t='bubble_lstick'
    pos:t='pw/2 -20/840pw -w, ph +30/452ph'
    <<^isSwapDirpadAndLStickBubblesPos>>pos:t='pw/2 -20/840pw -w, ph +30/452ph'<</isSwapDirpadAndLStickBubblesPos>>
    <<#isSwapDirpadAndLStickBubblesPos>>pos:t='-20/840pw-w, <<contactPointY>>/452ph-0.5h'<</isSwapDirpadAndLStickBubblesPos>>
    width:t='400/840pw'
    class:t='noIcon'
    <<#isGamepadCursorControlsEnabled>>text:t='#move_cursor'<</isGamepadCursorControlsEnabled>>
    <<^isGamepadCursorControlsEnabled>>text:t='#gamepad_cursor_control_splash/navigation_by_ui_objects'<</isGamepadCursorControlsEnabled>>
  }
  <</leftStick>>

  // R_STICK
  <<#rightStick>>
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/840pw-0.5w, <<contactPointY>>/452ph-0.5h'
    shadow {}
    tdiv { id:t='dot_rstick'; size:t='@dp, @dp'; pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute' }
  }
  controlsHelpPs4Bubble {
    id:t='bubble_rstick'
    pos:t='pw/2 +20/840pw, ph +30/452ph'
    width:t='400/840pw'
    class:t='noIcon'
    text:t='#scroll'
  }
  <</rightStick>>

  // ACTION_X
  <<#actionKey>>
  controlsHelpPs4Dot {
    pos:t='<<contactPointX>>/840pw-0.5w, <<contactPointY>>/452ph-0.5h'
    shadow {}
    tdiv { id:t='dot_actionx'; size:t='@dp, @dp'; pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute' }
  }
  controlsHelpPs4Bubble {
    id:t='bubble_actionx'
    pos:t='pw +20/840pw, <<contactPointY>>/452ph-0.5h'
    width:t='400/840pw'
    class:t='noIcon'
    text:t='#gamepad_cursor_control_splash/activation_of_selected_object'
  }
  <</actionKey>>
}
