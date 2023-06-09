enum WritingState {
  encoding,
  saving,
  idle;

  static WritingState fromName(String name) {
    switch (name) {
      case 'Encoding':
        return WritingState.encoding;
      case 'Saving':
        return WritingState.saving;
      case 'Idle':
        return WritingState.idle;
      default:
        throw Exception('Unknown WritingState: $name');
    }
  }

  String toName() {
    switch (this) {
      case WritingState.encoding:
        return 'Encoding';
      case WritingState.saving:
        return 'Saving';
      case WritingState.idle:
        return 'Idle';
      default:
        throw Exception('Unknown WritingState: $this');
    }
  }
}
