combination {
  <<#hasHoldButtonSign>>
  padding-left:t='-1@cIco -5*@sf/@pf'
  holdButtonSign { isCombination:t='yes' }
  <</hasHoldButtonSign>>

  <<#elements>>
  <<@element>>
  <<^last>>
  textareaNoTab {
    text:t="+"
    position:t='relative'
    top:t='ph/2 - h/2'
  }
  <</last>>
  <</elements>>
}
