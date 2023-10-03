<<#timersList>>
animSizeObj { //place div
  id:t='<<id>>';
  height:t='0';
  animation:t='hide';
  height-base:t='0'
  height-end:t='7'
  width-base:t='0';
  size-scale:t='screenheight'
  width-end:t='7'; //updated from script
  width:t='0';
  _size-timer:t='0'; //hidden by default

  massTransp {
    size:t='0.06@shHud, 0.06@shHud';
    //for centrate pos need be ((ParentWidthEnd - w)/2, (ParentHeightEnd - h)/2 )
    pos:t='pw/2-w/2, 0.035@shHud-h/2'
    position:t='absolute';
    _transp-timer:t='0'; //hidden by default

    <<#icon>>
    tdiv {
      id:t='icon';
      size:t='0.6pw, 0.6ph';
      position:t='absolute';
      pos:t='pw/2 - w/2, ph/2 - h/2';
      background-color:t='<<color>>';
      background-image:t='<<icon>>';
      background-repeat:t='aspect-ratio';
      background-svg-size:t='0.6pw, 0.6ph';
    }
    <</icon>>

    tdiv {
      size:t='1.167*pw, 1.167*ph'
      position:t='absolute'
      pos:t='pw/2 - w/2, ph/2 - h/2'
      background-svg-size:t='1.167*pw, 1.167*ph'
      background-color:t='#33555555'
      background-image:t='#ui/gameuiskin#circular_progress_1.svg'

      timeBar {
        id:t='timer';
        size:t='pw, ph';
        direction:t='forward';

        background-svg-size:t='1.167*p.p.w, 1.167*p.p.h'
        background-color:t='@white';
        background-image:t='#ui/gameuiskin#circular_progress_1.svg'
      }
    }

    <<#needSecondTimebar>>
    tdiv {
      id:t='available_timer_nest'
      size:t='1.5*pw, 1.5*ph'
      position:t='absolute'
      pos:t='pw/2 - w/2, ph/2 - h/2'
      background-svg-size:t='1.5*pw, 1.5*ph'
      background-color:t='#33555555'
      background-image:t='#ui/gameuiskin#circular_progress_2.svg'

      timeBar {
        id:t='available_timer'
        size:t='pw, ph'
        direction:t='forward'

        background-svg-size:t='1.3*p.p.w, 1.3*p.p.h'
        background-color:t='@white'
        background-image:t='#ui/gameuiskin#circular_progress_2.svg'
        inc-is-cyclic:t='no'
        inc-max:t='360'
      }
    }
    <</needSecondTimebar>>

    <<#needTimeText>>
    activeText {
      id:t='time_text';
      position:t='absolute';
      pos:t='pw/2 - w/2, ph/2 - h/2';
      hudFont:t='medium';

      behaviour:t='Timer';
      timer_interval_msec:t='1000'
      text:t='';
    }
    <</needTimeText>>
  }
}
<</timersList>>
