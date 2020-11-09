<<#rows>>
tr {
  td {
    highlight {}
    hr {}

    <<#iconLeft>>
    icon {
      ButtonContainer { ButtonImg {} }
      battleStateIco { id:t='battle-state-ico' class:t='' }
      unitContainer {
        img { id:t='torpedo-ico' class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_torpedo' }
        img { id:t='rocket-ico'  class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_missile' }
        img { id:t='bomb-ico'    class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_bomb'  }
        img { id:t='unit-ico'    class:t='unit'   background-image:t=''  shopItemType:t='' }
      }
    }
    <</iconLeft>>
    <<^iconLeft>>
    icon {
      unitContainer {
        img { id:t='unit-ico'    class:t='unit'   background-image:t=''  shopItemType:t='' }
        img { id:t='bomb-ico'    class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_bomb'  }
        img { id:t='rocket-ico'  class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_missile' }
        img { id:t='torpedo-ico' class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_torpedo' }
      }
      battleStateIco { id:t='battle-state-ico' class:t='' }
      ButtonContainer { ButtonImg {} }
    }
    <</iconLeft>>
    textareaNoTab {
      id:t='name'
      word-wrap:t='no'
      text:t=''
    }
    textareaNoTab {
      id:t='unit'
      word-wrap:t='no'
      text:t=''
    }
  }
}
<</rows>>
