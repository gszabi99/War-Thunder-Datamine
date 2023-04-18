<<#timersList>>
animSizeObj { //place div
  id:t='<<id>>';
  height:t='ph';

  animation:t='hide';
  size-scale:t='selfsize';
  width-base:t='0';
  width-end:t='100'; //updated from script
  width:t='1';
  _size-timer:t='0'; //hidden by default

  massTransp {
    size:t='0.06@shHud, 0.06@shHud';
    pos:t='50%pw-50%w, 50%ph-50%h';
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
