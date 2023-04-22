
import 'package:objectbox/objectbox.dart';

@Entity()
class Metadata {
  @Id()
  int id = 0;
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
