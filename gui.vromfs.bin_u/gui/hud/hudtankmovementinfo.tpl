<<#tankStates>>
tdiv {
  id:t='<<stateId>>'
  behaviour:t='bhvHudTankStates'
  css-hier-invalidate:t='yes'
  <<^isVisibleState>>display:t='hide'<</isVisibleState>>
  text {
    text:t='<<stateName>>'
    css-hier-invalidate:t='yes'
  }
  text {
    id:t='state_value'
    margin-left:t='0.005@shHud'
    css-hier-invalidate:t='yes'
    text:t='<<stateValue>>'
  }
}
<</tankStates>>
