combination {
  <<#hasHoldButtonSign>>
  holdButtonSign { margin-right:t='0.01@shHud' }
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
