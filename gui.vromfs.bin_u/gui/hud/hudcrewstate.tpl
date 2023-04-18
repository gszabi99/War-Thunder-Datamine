icon {
  id:t='crew_gunner';
  state:t='ok';
  hudCrewStatus:t='yes'
  icon_type:t='crew_gunner'
  tooltip:t=''
  pos:t='pw/2 + (0.42pw) * 0.972 - w/2, ph/2 + (0.42ph) * 0.25 - h/2';
  background-image:t='#ui/gameuiskin#crew_gunner_indicator.svg'

  timeBar {
    id:t='transfere_indicatior';
  }
}

icon {
  id:t='crew_driver';
  state:t='ok';
  hudCrewStatus:t='yes';
  icon_type:t='crew_driver'
  tooltip:t=''
  pos:t='pw/2 + (0.42pw) * 0.72 - w/2, ph/2 + (0.42ph) * 0.70- h/2';
  background-image:t='#ui/gameuiskin#crew_driver_indicator.svg'

  timeBar {
    id:t='transfere_indicatior';
  }

  drivingDirectionModeStatus {
    id:t='driving_direction_mode'
    behaviour:t='bhvUpdateByWatched'
    state:t='off'
    tooltip:t='#hotkeys/ID_ENABLE_GM_DIRECTION_DRIVING'
    value:t='<<drivingDirectionModeValue>>'
  }
}

icon {
  id:t='crew_count';
  hudCrewStatus:t='yes';
  icon_type:t='crew_count'
  tooltip:t='#hud_tank_crew_members_count'
  pos:t='0, 0.64ph - h/2'
  background-image:t='#ui/gameuiskin#crew.svg'

  text {
    id:t='crew_count_text';
    position:t='absolute';
    pos:t='pw, ph - h'
    text-align:t='right';
    text:t='';
  }
}

icon {
  id:t='crew_distance';
  hudCrewStatus:t='yes'
  state:t='ok';
  tooltip:t=''
  pos:t='pw/2 + (0.42pw) * 0.23 - w/2, ph/2 + (0.42ph) * 0.97 - h/2'
  background-image:t='#ui/gameuiskin#overview_icon.svg'

  tdiv {
    id:t='cooldown'
    re-type:t='sector';
    sector-angle-1:t='0';
    sector-angle-2:t='0';
    size:t='pw, ph';
    position:t='absolute';
    background-color:t='@white';
    background-image:t='#ui/gameuiskin#timebar.svg'
    background-svg-size:t='pw, ph'
  }

  icon {
    hudCrewStatus:t='yes'
    size:t='pw, ph';
    state:t='ok';
    position:t='absolute';
    background-color:t='@white';
    background-image:t='#ui/gameuiskin#timebar.svg'
    background-svg-size:t='pw, ph'
  }
}
