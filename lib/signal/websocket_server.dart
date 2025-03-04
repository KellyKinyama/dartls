import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fingerprint.dart';
import 'sdp.dart';

Future<void> main() async {
  // Start WebSocket Server on localhost at port 8080
  final server = await HttpServer.bind('localhost', 8080);
  print('WebSocket Proxy Server running on ws://localhost:8080');

  await for (var request in server) {
    if (request.uri.path == '/ws') {
      handleWebSocketProxy(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    }
  }
}

void handleWebSocketProxy(HttpRequest request) async {
  final webSocket = await WebSocketTransformer.upgrade(request);
  print('Client connected');

  // "v=0\r\no=- 5836237883668594579 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\n","type":"offer"}

  webSocket.listen(
    (message) {
      print("Received: $message");
      var data = jsonDecode(message);

      if (data["offer"]['type'] == 'offer' && data["offer"]['sdp'] != null) {
        print("Received SDP Offer");

        // String fingerprint =
        //     'E5723D8CDB6C27705559BFA6777A6FE82AB2456691E140B8E22914A13060B188F';
        // String sdpAnswer = createSdpAnswer();

        var agent = Agent(
          ufrag: 'ufrag123',
          pwd: 'pwd123',
          fingerprintHash: fingerprint(),
          iceCandidates: [
            SdpMediaCandidate(
                ip: '127.0.0.1',
                port: 4444,
                type: CandidateType.host,
                transport: TransportType.udp),
          ],
        );

        var offer = agent.generateSdpOffer();

        final answer = jsonEncode({
          "offer":
              r'{"sdp":"v=0\r\no=- 5836237883668594579 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\n","type":"answer"}'
        });

        print("Sending SDP Answer");
        webSocket.add(answer);
      }

      if (data["offer"].containsKey('candidate')) {
        print("Received ICE Candidate: ${data['candidate']}");
        // Echo the candidate back to simulate trickle ICE signaling
        webSocket.add(jsonEncode({
          "candidate": data['candidate'],
        }));
      }
    },
    onDone: () {
      print("Client disconnected");
      webSocket.close();
    },
    onError: (error) {
      print("WebSocket Error: $error");
    },
  );
}

String createSdpAnswer() {
  return '''
v=0
o=- 634445219885578297 2 IN IP4 127.0.0.1
s=-
c=IN IP4 127.0.0.1
t=0 0
m=audio 4444 RTP/SAVP 96 97
a=rtpmap:96 opus/48000/2
a=rtpmap:97 PCMU/8000
a=setup:passive
a=mid:audio
a=recvonly
a=fingerprint:sha-256 ${fingerprint()}
a=ice-ufrag:ice123
a=ice-pwd:password123
a=candidate:1 1 UDP 2122252543 127.0.0.1 4444 typ host
a=end-of-candidates
''';
}
