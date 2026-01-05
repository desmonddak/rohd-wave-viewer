// Wrapper that selects the correct embed implementation for the platform.
import 'src/platform/embed_io.dart'
    if (dart.library.js_interop) 'src/platform/embed_web.dart';

void signalEmbedReady([Map<String, dynamic>? info]) =>
    signalEmbedReadyImpl(info);
void postMessageToHost(Object message) => postMessageToHostImpl(message);
bool isShiftDownFromJs() => isShiftDownFromJsImpl();
