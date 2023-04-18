tdiv {
  id:t='mainActionButton';
  behaviour:t='BhvHint'
  position:t='absolute';
  pos:t='pw/2 - w/2, -h - 0.005@shHud';
  value:t='{{<<mainShortcutId>>}}';
}
<<#activatedShortcutId>>
tdiv {
  id:t='activatedActionButton';
  behaviour:t='BhvHint'
  position:t='absolute';
  pos:t='pw/2 - w/2, -h - 0.005@shHud';
  value:t='{{<<activatedShortcutId>>}}';
  display:t='hide';
}
<</activatedShortcutId>>
tdiv {
  id:t='cancelButton';
  behaviour:t='BhvHint'
  position:t='absolute';
  pos:t='pw/2 - w/2, h + 0.005@shHud';
  value:t='{{<<cancelShortcutId>>}}';
  display:t='hide';
}
