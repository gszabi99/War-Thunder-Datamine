<<#items>>
action_bar_item {
  id:t='<<id>>';
  size:t='ph, ph';
  margin:t='1@dp, 0';
  padding:t='1@dp';
  background-color:t='#77333333';
  selected:t='<<selected>>';
  active:t='<<active>>';
  enabled:t='yes';
  css-hier-invalidate:t='yes';

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

    img {
      id:t='action_icon'
      size:t='pw, ph';
      background-image:t='<<icon>>';
    }
  }

  tdiv {
    id:t='<<id>>_target_point';
    pos:t='50%pw-50%w, 0';
    position:t='absolute';
    size:t='1*@sf/@pf_outdated, 1*@sf/@pf_outdated'
  }
}
<</items>>