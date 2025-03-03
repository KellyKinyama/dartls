import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main() async {
  // Target WebSocket server URI to proxy to
  // final targetUri = Uri.parse('ws://example.com/socket');

  // Start the proxy server on localhost at port 8080
  final server = await HttpServer.bind('localhost', 8080);
  print('WebSocket Proxy Server running on ws://localhost:8080');

  await for (var request in server) {
    if (request.uri.path == '/ws') {
      handleWebSocketProxy(request);
    } else {
      // Handle other requests if needed
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    }
  }
}

// Handle incoming WebSocket connections and proxy them to the target server
void handleWebSocketProxy(HttpRequest request) async {
  // final targetChannel = WebSocketChannel.connect(targetUri);

  // Upgrade the request to a WebSocket connection
  final webSocket = await WebSocketTransformer.upgrade(request);

  // Forward data from the client's WebSocket to the target WebSocket server
  final clientToTarget = webSocket.listen(
    (message) {
      print("Recieve: $message");
    },
    onDone: () {
      // targetChannel.sink.close();
      print("Client disconnected");
      webSocket.close();
    },
  );

  // Forward data from the target WebSocket server to the client

  // Close both connections when done
  // Close both connections when done
}
