bool isComposerPanelOpen({
  required bool expressionPanelOpen,
  required bool attachmentPanelOpen,
}) {
  return expressionPanelOpen || attachmentPanelOpen;
}

bool shouldShowComposerSafeAreaBar({
  required double safeAreaBottom,
  required double bottomSlotHeight,
  required bool isPanelOpen,
  required double keyboardInsetBottom,
}) {
  return safeAreaBottom > 0 &&
      bottomSlotHeight <= 0 &&
      !isPanelOpen &&
      keyboardInsetBottom <= 0;
}

bool usesInlineAttachmentPanel({
  required bool isNativeMobileOs,
  required bool isMobileLayout,
}) {
  return isNativeMobileOs && isMobileLayout;
}

enum DockedComposerPanel { expression, attachment }

DockedComposerPanel? resolveDockedComposerPanel({
  required bool expressionPanelOpen,
  required bool attachmentPanelOpen,
  required bool keyboardTakingOver,
  required DockedComposerPanel? previous,
}) {
  if (attachmentPanelOpen) {
    return DockedComposerPanel.attachment;
  }
  if (expressionPanelOpen) {
    return DockedComposerPanel.expression;
  }
  if (keyboardTakingOver) {
    return previous;
  }
  return null;
}
