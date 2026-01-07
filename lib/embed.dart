// Facade-based wrapper for embed helpers
import 'src/platform/platform.dart' as plat;

void signalEmbedReady([Map<String, dynamic>? info]) =>
    plat.signalEmbedReadyImpl(info);
void postMessageToHost(Object message) => plat.postMessageToHostImpl(message);
bool isShiftDownFromJs() => plat.isShiftDownFromJsImpl();
