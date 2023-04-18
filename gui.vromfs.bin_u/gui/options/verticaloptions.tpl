<<#rows>>
tr{
  id:t='tr_<<id>>'

  <<#leftInfoRows>>
  td {
    <<#leftInfoWidth>>
      width:t='<<leftInfoWidth>>'
    <</leftInfoWidth>>

    <<#leftCellType>>
      cellType:t='<<leftCellType>>'
    <</leftCellType>>

    optiontext {
      text:t='<<label>>'
    }
  }
  <</leftInfoRows>>

  td {
    width:t='pw'
    cellType:t='top'
    overflow-x:t='hidden'
    <<^name>>display:t='hide'<</name>>
    optiontext {
      text:t ='<<name>>'
      padding-top:t='4@dp'
    }
  }

  td {
    cellType:t='bottom'
    <<@option>>

    optionValueText {
      id:t='value_<<id>>'
      <<#valueWidth>>width:t='<<valueWidth>>'<</valueWidth>>
    }
  }

  <<#infoRows>>
  td {
    cellType:t='info'

    optiontext {
      width:t='fw'
      style:t='text-align:left;'
      text:t='<<label>>'
    }
    <<#valueId>>
    optionValueText {
      id:t='<<valueId>>'
      width:t='<<valueWidth>>'
      text:t=''
    }
    <</valueId>>
  }
  <</infoRows>>
}
<</rows>>
