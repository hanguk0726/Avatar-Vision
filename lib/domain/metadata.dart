import 'package:objectbox/objectbox.dart';

@Entity()
class Metadata {
  int id = 0; // required for ObjectBox to work
  @Index()
  @Unique()
  String videoTitle;

  int timestamp;

  String? note;

  String? tags;

  String? thumbnail;

  Metadata({
    required this.videoTitle,
    required this.timestamp,
    this.note,
    this.tags,
    this.thumbnail,
  });
}
