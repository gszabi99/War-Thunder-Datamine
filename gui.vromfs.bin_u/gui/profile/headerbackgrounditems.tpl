<<#items>>
headerBackgroundItem {
  id:t='<<id>>'
  width:t='pw'
  css-hier-invalidate:t='yes'
  textarea {
    text:t='<<headerName>>'
  }

  <<#isDisabled>>
  disabled:t='yes'
  LockedImg { statusLock:t='headerImage' }
  <</isDisabled>>
}
<</items>>