icon {
  id:t='tracks_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.999 - w/2, ph/2 - (0.42ph) * 0.044 - h/2';
  background-image:t='#ui/gameuiskin#track_state_indicator.svg'

}

icon {
  id:t='turret_drive_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.947 - w/2, ph/2 - (0.42ph) * 0.402 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#turret_gear_state_indicator.svg'
}

icon {
  id:t='gun_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.729 - w/2, ph/2 - (0.42ph) * 0.713 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#gun_state_indicator.svg'
}

icon {
  id:t='engine_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.396 - w/2, ph/2 - (0.42ph) * 0.926 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#engine_state_indicator.svg'
}

debuffsTextNest {
  behaviour:t='bhvUpdateByWatched'
  position:t='absolute'
  pos:t='pw/2 - w/2, 0.08ph - h/2'
  css-hier-invalidate:t='yes'
  value:t='<<stabilizerValue>>'
  display:t='hide'

  text {
    id:t='stabilizer'
    hudTankDebuff:t='yes'
    state:t='<<stateValue>>'
    text:t='#HUD/TXT_STABILIZER'
    css-hier-invalidate:t='yes'
  }
}

debuffsTextNest {
  behaviour:t='bhvUpdateByWatched'
  position:t='absolute'
  rotation:t='25'
  pos:t='(pw/2 - w/2) + 0.16pw, 0.11ph - h/2'
  css-hier-invalidate:t='yes'
  value:t='<<lwsValue>>'
  display:t='hide'

  text {
    id:t='lws'
    hudTankDebuff:t='yes'
    state:t='<<stateValue>>'
    text:t='#HUD/TXT_LWS'
    css-hier-invalidate:t='yes'
  }
}

debuffsTextNest {
  behaviour:t='bhvUpdateByWatched'
  position:t='absolute'
  rotation:t='38'
  pos:t='(pw/2 - w/2) + 0.30pw, 0.20ph - h/2'
  css-hier-invalidate:t='yes'
  value:t='<<ircmValue>>'
  display:t='hide'

  text {
    id:t='ircm'
    hudTankDebuff:t='yes'
    state:t='<<stateValue>>'
    text:t='#HUD/TXT_IRCM'
    css-hier-invalidate:t='yes'
  }
}

icon {
  id:t='fire_status';
  display:t='hide';
  pos:t='ph/7 * 2.5, ph - h';
  background-color:t='@red';
  background-image:t='#ui/gameuiskin#fire_indicator.svg'
}
