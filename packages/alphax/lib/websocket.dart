/// Transport-neutral WebSocket lifecycle contracts.
library;

export 'src/alpha_x_capabilities.dart' show AlphaXSupport;
export 'src/alpha_x_cancellation.dart' show AlphaXCancellationToken;
export 'src/alpha_x_errors.dart'
    show
        AlphaXCancelledException,
        AlphaXCancellationException,
        AlphaXErrorKind,
        AlphaXException,
        AlphaXTimeoutException;
export 'src/alpha_x_timeout.dart' show AlphaXTimeoutKind;
export 'src/alpha_x_websocket.dart';
