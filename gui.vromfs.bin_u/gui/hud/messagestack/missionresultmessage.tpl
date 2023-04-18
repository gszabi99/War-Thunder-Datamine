message {
  height:t='1@missionResultNestHeight'
  width:t='10h'
  pos:t='50%pw-50%w, 50%ph-50%h';
  position:t='absolute'
  css-hier-invalidate:t='yes'

  missionResultText {
    id:t='mission_result_box'
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute'
    text-align:t='center'
    text:t='<<text>>'
    <<#useMoveOut>> display:t='hide' <</useMoveOut>>
    <<^useMoveOut>>
      anim_transparency:t='yes'
      color-factor:t='0'
    <</useMoveOut>>
  }
}