textareaNoTab {
  id:t='server_message';
  position:t='absolute';
  pos:t='50%pw-50%w, 2@topBarHeight';
  text:t='';
  overlayTextColor:t='warning'
  max-width:t='0.4sw';
  input-transparent:t='yes'
}

tdiv{
  position:t='absolute';
  pos:t='0, 13*@sf/@pf_outdated';
  size:t='pw, 0.057@sf';
  input-transparent:t='yes';
  display:t='hide';
  tdiv{
    re-type:t='9rect';
    position:t='relative';
    top:t='4*@sf/@pf_outdated';
    size:t='pw, ph';
    foreground-image:t='#ui/gameuiskin#button_bright_bg';
    foreground-position:t='16';
    foreground-repeat:t='expand';
    foreground-color:t='#aa000000';
    input-transparent:t='yes';
    if_target_pc:t='yes';
  }
}

tdiv{
  position:t='absolute';
  pos:t='0, 8*@sf/@pf_outdated';
  size:t='pw, 0.0565@sf';
  input-transparent:t='yes';
  display:t='hide';
  tdiv{
    re-type:t='9rect';
    position:t='relative';
    top:t='4*@sf/@pf_outdated';
    size:t='pw, ph';
    foreground-image:t='#ui/gameuiskin#button_bright_bg';
    foreground-position:t='16';
    foreground-repeat:t='expand';
    foreground-color:t='#ffffff';
    input-transparent:t='yes';
    if_target_pc:t='yes';
  }
}

Button_text {
  id:t='to_battle_button';
  position:t='absolute';
  pos:t='50%pw-50%w, 3';
  noMargin:t='yes'
  class:t='battle';
  text:t='#mainmenu/toBattle/short';
  on_click:t='onStart';
  css-hier-invalidate:t='yes';
  iconPos:t='middleBottom';
  isCancel:t='no';

  <<^enableEnterKey>>
    noEnter:t='yes'
  <</enableEnterKey>>

  style:t='height: 1@topMenuBattleButtonHeight; min-width: pw - 14*@sf/@pf_outdated;'

  buttonWink {
    _transp-timer:t='0';
  }

  buttonGlance {}

  pattern { type:t='bright_texture' }

  btnText {
    id:t='to_battle_button_text';
    text:t='#mainmenu/toBattle/short';
    style:t='text-shade-color: #55000000; color: #ffffff; text-shade:smooth:48; text-shade-x:0; text-shade-y:0;';
  }

  focus_border{}

  btnName:t='X'
  ButtonImg{ id:t='to_battle_console_image' }
}
