<<#battle>>
wwBattleIcon {
  id:t='<<getId>>'
  status:t='<<getStatus>>'
  <<#getTooltip>>
  tooltip:t='<<getTooltip>>'
  <</getTooltip>>
  <<#addClickCb>>
    behavior:t='button'
    on_click:t ='onClickBattle'
    on_hover:t='onHoverBattle'
    on_unhover:t='onHoverLostBattle'
  <</addClickCb>>
}
<</battle>>
