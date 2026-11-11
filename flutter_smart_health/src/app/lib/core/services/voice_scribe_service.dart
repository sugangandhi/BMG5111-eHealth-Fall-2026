export 'voice_scribe_types.dart';
export 'voice_scribe_service_stub.dart'
    if (dart.library.js) 'voice_scribe_service_web.dart'
    if (dart.library.io) 'voice_scribe_service_io.dart';
