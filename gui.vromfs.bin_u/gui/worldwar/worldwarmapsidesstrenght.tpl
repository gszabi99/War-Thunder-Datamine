tdiv {
  pos:t='50%pw-50%w, 0'
  position:t='relative'
  margin:t='0, 1@blockInterval'

  <<#armyCountryImg1>>
  tdiv {
    width:t='15%p.p.w'
    top:t='50%ph-50%h'
    position:t='relative'

    cardImg {
      background-image:t='<<image>>'
    }
  }
  <</armyCountryImg1>>

  textAreaCentered {
    id:t='label_commands'
    width:t='48%p.p.w'
    top:t='50%ph-50%h'
    position:t='relative'
    text:t='#worldWar/armyStrength'
    hideEmptyText:t='yes'
    mediumFont:t='yes'
    overlayTextColor:t='active'
  }

  <<#armyCountryImg2>>
  tdiv {
    width:t='15%p.p.w'
    top:t='50%ph-50%h'
    position:t='relative'

    cardImg {
      left:t='pw-w'
      position:t='relative'
      background-image:t='<<image>>'
    }
  }
  <</armyCountryImg2>>
}

tdiv {
  width:t='pw'
  margin-bottom:t='1@blockInterval'
  bgcolor:t='@objectiveHeaderBackground'

  tdiv {
    height:t='1@statusPanelHeight'
    pos:t='50%pw-50%w, 0'
    position:t='relative'

    textareaNoTab {
      width:t='15%p.p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      text:t='<<side1TotalVehicle>>'
      overlayTextColor:t='active'
    }
    textAreaCentered {
      width:t='48%p.p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      text:t='#worldWar/totalUnits'
      overlayTextColor:t='active'
    }
    textareaNoTab {
      width:t='15%p.p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      text:t='<<side2TotalVehicle>>'
      talign:t='right'
      overlayTextColor:t='active'
    }
  }
}

<<#unitString>>
  tdiv {
    padding-top:t='1@wwMapInterlineStrengthPadding'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    img {
      background-image:t='<<unitIcon>>'
      shopItemType:t='<<shopItemType>>'
      size:t='1@tableIcoSize, 1@tableIcoSize'
      background-svg-size:t='@tableIcoSize, @tableIcoSize'
      background-repeat:t='aspect-ratio'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin-right:t='1@blockInterval'
    }
    textareaNoTab {
      text:t='<<side1UnitCount>>'
      width:t='15%p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    textAreaCentered {
      text:t='<<unitName>>'
      width:t='48%p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    textareaNoTab {
      text:t='<<side2UnitCount>>'
      width:t='15%p.p.w'
      talign:t='right'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    img {
      background-image:t='<<unitIcon>>'
      shopItemType:t='<<shopItemType>>'
      size:t='@tableIcoSize, @tableIcoSize'
      background-svg-size:t='@tableIcoSize, @tableIcoSize'
      background-repeat:t='aspect-ratio'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin-left:t='1@blockInterval'
    }
  }
<</unitString>>
