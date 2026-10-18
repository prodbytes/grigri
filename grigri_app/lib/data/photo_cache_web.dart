import 'package:flutter/painting.dart';

/// The web loads photos as before: the browser's own cache keeps them, as
/// their Cache-Control says (a year: their keys never change).
ImageProvider Function(Uri url) defaultPhotoImage() =>
    (url) => NetworkImage(url.toString());
