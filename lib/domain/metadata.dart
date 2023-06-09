import 'package:objectbox/objectbox.dart';

@Entity()
class Metadata {
  int id = 0; // required for ObjectBox to work

  @Index()
  @Unique()
  int timestamp;

  String title;

  String? note;

  String? tags;

  String? thumbnail;

  Metadata({
    required this.title,
    required this.timestamp,
    this.note,
    this.tags,
    this.thumbnail,
  });
}
