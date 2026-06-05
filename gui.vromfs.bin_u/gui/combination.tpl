combination {
  <<#activationTypeImg>>
  hasActivationTypeImg:t='yes'
  activationTypeImg {
    background-image:t='#ui/gameuiskin#<<activationTypeImg>>'
  }
  <</activationTypeImg>>

  combinationBackground {
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
}
