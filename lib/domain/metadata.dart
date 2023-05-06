import 'package:objectbox/objectbox.dart';

@Entity()
class Metadata {
  int id = 0; // required for ObjectBox to work
  String videoTitle;

  @Index()
  @Unique()
  int timestamp = DateTime.now().millisecondsSinceEpoch;

  String? note;

  String? tags;

  String? thumbnail;

  Metadata({
    required this.videoTitle,
    this.note,
    this.tags,
    this.thumbnail,
  });
}
