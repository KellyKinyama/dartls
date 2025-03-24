import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../src/sdp/sdp_transform.dart';
import 'fingerprint.dart';
import 'sdp3.dart';

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

  // "v=0\\r\\no=- 5836237883668594579 2 IN IP4 127.0.0.1\\r\\ns=-\\r\\nt=0 0\\r\\na=extmap-allow-mixed\\r\\na=msid-semantic: WMS\\r\\n","type":"offer"}

  webSocket.listen(
    (message) {
      print("Received: $message");
      var data = jsonDecode(message);

      if (data["offer"]['type'] == 'offer' && data["offer"]['sdp'] != null) {
        print("Received SDP Offer");

        // String fingerprint =
        //     'E5723D8CDB6C27705559BFA6777A6FE82AB2456691E140B8E22914A13060B188F';
        // String sdpAnswer = createSdpAnswer();

        final sdpOffer = generateSdpOffer();

        final answer = jsonEncode({
          "offer": {"sdp": sdpOffer.toString(), "type": "offer"}
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
  return '{"offer":{"sdp":"v=0\\r\\no=- 7093843651144175105 2 IN IP4 127.0.0.1\\r\\ns=-\\r\\nt=0 0\\r\\na=group:BUNDLE 0\\r\\na=extmap-allow-mixed\\r\\na=msid-semantic: WMS 7673c106-987c-4b17-a982-a32f8b07531a\\r\\nm=video 9 UDP/TLS/RTP/SAVPF 96 97 103 104 107 108 109 114 115 116 117 118 39 40 45 46 98 99 100 101 119 120 123 124 125\\r\\nc=IN IP4 0.0.0.0\\r\\na=rtcp:9 IN IP4 0.0.0.0\\r\\na=ice-ufrag:2YG8\\r\\na=ice-pwd:cNu4hw9eMeBLEqIqomvb9AlH\\r\\na=ice-options:trickle\\r\\na=fingerprint:sha-256 5D:71:08:09:97:56:1B:01:A7:7A:51:4D:D5:95:D4:5E:D3:EE:E0:94:95:B8:0E:17:AB:43:EC:08:A5:BD:41:5E\\r\\na=setup:actpass\\r\\na=mid:0\\r\\na=extmap:1 urn:ietf:params:rtp-hdrext:toffset\\r\\na=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\\r\\na=extmap:3 urn:3gpp:video-orientation\\r\\na=extmap:4 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\\r\\na=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\\r\\na=extmap:6 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\\r\\na=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing\\r\\na=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space\\r\\na=extmap:9 urn:ietf:params:rtp-hdrext:sdes:mid\\r\\na=extmap:10 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\\r\\na=extmap:11 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\\r\\na=sendrecv\\r\\na=msid:7673c106-987c-4b17-a982-a32f8b07531a 357df3e2-9834-4c33-9ae1-185cb2d911a7\\r\\na=rtcp-mux\\r\\na=rtcp-rsize\\r\\na=rtpmap:96 VP8/90000\\r\\na=rtcp-fb:96 goog-remb\\r\\na=rtcp-fb:96 transport-cc\\r\\na=rtcp-fb:96 ccm fir\\r\\na=rtcp-fb:96 nack\\r\\na=rtcp-fb:96 nack pli\\r\\na=rtpmap:97 rtx/90000\\r\\na=fmtp:97 apt=96\\r\\na=rtpmap:103 H264/90000\\r\\na=rtcp-fb:103 goog-remb\\r\\na=rtcp-fb:103 transport-cc\\r\\na=rtcp-fb:103 ccm fir\\r\\na=rtcp-fb:103 nack\\r\\na=rtcp-fb:103 nack pli\\r\\na=fmtp:103 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f\\r\\na=rtpmap:104 rtx/90000\\r\\na=fmtp:104 apt=103\\r\\na=rtpmap:107 H264/90000\\r\\na=rtcp-fb:107 goog-remb\\r\\na=rtcp-fb:107 transport-cc\\r\\na=rtcp-fb:107 ccm fir\\r\\na=rtcp-fb:107 nack\\r\\na=rtcp-fb:107 nack pli\\r\\na=fmtp:107 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42001f\\r\\na=rtpmap:108 rtx/90000\\r\\na=fmtp:108 apt=107\\r\\na=rtpmap:109 H264/90000\\r\\na=rtcp-fb:109 goog-remb\\r\\na=rtcp-fb:109 transport-cc\\r\\na=rtcp-fb:109 ccm fir\\r\\na=rtcp-fb:109 nack\\r\\na=rtcp-fb:109 nack pli\\r\\na=fmtp:109 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\\r\\na=rtpmap:114 rtx/90000\\r\\na=fmtp:114 apt=109\\r\\na=rtpmap:115 H264/90000\\r\\na=rtcp-fb:115 goog-remb\\r\\na=rtcp-fb:115 transport-cc\\r\\na=rtcp-fb:115 ccm fir\\r\\na=rtcp-fb:115 nack\\r\\na=rtcp-fb:115 nack pli\\r\\na=fmtp:115 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42e01f\\r\\na=rtpmap:116 rtx/90000\\r\\na=fmtp:116 apt=115\\r\\na=rtpmap:117 H264/90000\\r\\na=rtcp-fb:117 goog-remb\\r\\na=rtcp-fb:117 transport-cc\\r\\na=rtcp-fb:117 ccm fir\\r\\na=rtcp-fb:117 nack\\r\\na=rtcp-fb:117 nack pli\\r\\na=fmtp:117 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=4d001f\\r\\na=rtpmap:118 rtx/90000\\r\\na=fmtp:118 apt=117\\r\\na=rtpmap:39 H264/90000\\r\\na=rtcp-fb:39 goog-remb\\r\\na=rtcp-fb:39 transport-cc\\r\\na=rtcp-fb:39 ccm fir\\r\\na=rtcp-fb:39 nack\\r\\na=rtcp-fb:39 nack pli\\r\\na=fmtp:39 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=4d001f\\r\\na=rtpmap:40 rtx/90000\\r\\na=fmtp:40 apt=39\\r\\na=rtpmap:45 AV1/90000\\r\\na=rtcp-fb:45 goog-remb\\r\\na=rtcp-fb:45 transport-cc\\r\\na=rtcp-fb:45 ccm fir\\r\\na=rtcp-fb:45 nack\\r\\na=rtcp-fb:45 nack pli\\r\\na=fmtp:45 level-idx=5;profile=0;tier=0\\r\\na=rtpmap:46 rtx/90000\\r\\na=fmtp:46 apt=45\\r\\na=rtpmap:98 VP9/90000\\r\\na=rtcp-fb:98 goog-remb\\r\\na=rtcp-fb:98 transport-cc\\r\\na=rtcp-fb:98 ccm fir\\r\\na=rtcp-fb:98 nack\\r\\na=rtcp-fb:98 nack pli\\r\\na=fmtp:98 profile-id=0\\r\\na=rtpmap:99 rtx/90000\\r\\na=fmtp:99 apt=98\\r\\na=rtpmap:100 VP9/90000\\r\\na=rtcp-fb:100 goog-remb\\r\\na=rtcp-fb:100 transport-cc\\r\\na=rtcp-fb:100 ccm fir\\r\\na=rtcp-fb:100 nack\\r\\na=rtcp-fb:100 nack pli\\r\\na=fmtp:100 profile-id=2\\r\\na=rtpmap:101 rtx/90000\\r\\na=fmtp:101 apt=100\\r\\na=rtpmap:119 H264/90000\\r\\na=rtcp-fb:119 goog-remb\\r\\na=rtcp-fb:119 transport-cc\\r\\na=rtcp-fb:119 ccm fir\\r\\na=rtcp-fb:119 nack\\r\\na=rtcp-fb:119 nack pli\\r\\na=fmtp:119 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=64001f\\r\\na=rtpmap:120 rtx/90000\\r\\na=fmtp:120 apt=119\\r\\na=rtpmap:123 red/90000\\r\\na=rtpmap:124 rtx/90000\\r\\na=fmtp:124 apt=123\\r\\na=rtpmap:125 ulpfec/90000\\r\\na=ssrc-group:FID 4077865842 2827074001\\r\\na=ssrc:4077865842 cname:GP8rH5Z9maAlcYek\\r\\na=ssrc:4077865842 msid:7673c106-987c-4b17-a982-a32f8b07531a 357df3e2-9834-4c33-9ae1-185cb2d911a7\\r\\na=ssrc:2827074001 cname:GP8rH5Z9maAlcYek\\r\\na=ssrc:2827074001 msid:7673c106-987c-4b17-a982-a32f8b07531a 357df3e2-9834-4c33-9ae1-185cb2d911a7\\r\\n","type":"offer"}} ';
}
