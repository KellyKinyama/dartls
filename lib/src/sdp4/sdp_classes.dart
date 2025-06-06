import 'package:sdp_transform/sdp_transform.dart';

enum MediaType { video, audio }

enum CandidateType { host }

enum TransportType { udp, tcp }

enum FingerprintType { sha256 }

class SdpMediaCandidate {
  final String ip;
  final int port;
  final CandidateType type;
  final TransportType transport;

  SdpMediaCandidate({
    required this.ip,
    required this.port,
    required this.type,
    required this.transport,
  });

  @override
  String toString() {
    return 'Type: <u>${type.name}</u>, Transport: <u>${transport.name}</u>, Ip: <u>$ip</u>, Port: <u>$port</u>';
  }
}

class SdpMedia {
  final int mediaId;
  final MediaType type;
  final String ufrag;
  final String pwd;
  final FingerprintType fingerprintType;
  final String fingerprintHash;
  final List<SdpMediaCandidate> candidates;
  final String payloads;
  final String rtpCodec;

  SdpMedia({
    required this.mediaId,
    required this.type,
    required this.ufrag,
    required this.pwd,
    required this.fingerprintType,
    required this.fingerprintHash,
    required this.candidates,
    required this.payloads,
    required this.rtpCodec,
  });

  @override
  String toString() {
    final candidatesStr = candidates.map((c) => '[SdpCandidate] $c').join("\n");
    return 'MediaId: <u>$mediaId</u>, Type: $type, Ufrag: <u>$ufrag</u>, Pwd: <u>$pwd</u>\n'
        'FingerprintType: <u>${fingerprintType.name}</u>, FingerprintHash: <u>$fingerprintHash</u>\n'
        'Candidates:\n+$candidatesStr';
  }
}

class SdpMessage {
  final String conferenceName;
  final String sessionId;
  final List<SdpMedia> mediaItems;

  SdpMessage({
    this.conferenceName = '',
    required this.sessionId,
    required this.mediaItems,
  });

  factory SdpMessage.fromMap(Map<String, dynamic> offer) {
    final sessionId = offer['origin']['sessionId'] as String;
    final mediaList = offer['media'] as List;
    final mediaItems = <SdpMedia>[];

    for (final mediaItem in mediaList) {
      final candidatesRaw = mediaItem['candidates'] ?? [];
      final fingerprintRaw = mediaItem['fingerprint'] ?? offer['fingerprint'];

      final candidates = (candidatesRaw as List).map((c) {
        return SdpMediaCandidate(
          ip: c['ip'],
          port: c['port'],
          type: CandidateType.values.firstWhere((e) => e.name == c['type']),
          transport:
              TransportType.values.firstWhere((e) => e.name == c['transport']),
        );
      }).toList();

      mediaItems.add(SdpMedia(
        mediaId: 0, // Not provided in original map
        type: MediaType.values.firstWhere((e) => e.name == mediaItem['type']),
        ufrag: mediaItem['iceUfrag'],
        pwd: mediaItem['icePwd'],
        fingerprintType: FingerprintType.values.firstWhere((e) =>
            e.name.replaceAll('-', '') ==
            fingerprintRaw['type'].replaceAll('-', '')),
        fingerprintHash: fingerprintRaw['hash'],
        candidates: candidates,
        payloads: mediaItem['payloads'] ?? '',
        rtpCodec: mediaItem['rtpCodec'] ?? '',
      ));
    }

    return SdpMessage(sessionId: sessionId, mediaItems: mediaItems);
  }

  @override
  String toString() {
    final mediaStrings = mediaItems.map((m) => '[SdpMedia] $m').join("\n");
    return 'SessionID: <u>$sessionId</u>\nMediaItems:\n+$mediaStrings';
  }
}

// Dummy placeholders for external references:
class AgentCandidate {
  final String ip;
  final int port;
  AgentCandidate({required this.ip, required this.port});
}

class ServerAgent {
  final String ufrag;
  final String pwd;
  final String fingerprintHash;
  final List<AgentCandidate> iceCandidates;
  ServerAgent(
      {required this.ufrag,
      required this.pwd,
      required this.fingerprintHash,
      required this.iceCandidates});
}

SdpMessage generateSdpOffer(ServerAgent agent, {bool requestAudio = true}) {
  final candidates = agent.iceCandidates
      .map((c) => SdpMediaCandidate(
            ip: c.ip,
            port: c.port,
            type: CandidateType.host,
            transport: TransportType.udp,
          ))
      .toList();

  final mediaItems = <SdpMedia>[
    SdpMedia(
      mediaId: 0,
      type: MediaType.video,
      ufrag: agent.ufrag,
      pwd: agent.pwd,
      fingerprintType: FingerprintType.sha256,
      fingerprintHash: agent.fingerprintHash,
      candidates: candidates,
      payloads: '96', // rtp.PayloadTypeVP8.CodecCodeNumber()
      rtpCodec: 'VP8/90000', // rtp.PayloadTypeVP8.CodecName()
    )
  ];

  if (requestAudio) {
    mediaItems.add(SdpMedia(
      mediaId: 1,
      type: MediaType.audio,
      ufrag: agent.ufrag,
      pwd: agent.pwd,
      fingerprintType: FingerprintType.sha256,
      fingerprintHash: agent.fingerprintHash,
      candidates: candidates,
      payloads: '109', // rtp.PayloadTypeOpus.CodecCodeNumber()
      rtpCodec: 'OPUS/48000/2', // rtp.PayloadTypeOpus.CodecName()
    ));
  }

  return SdpMessage(sessionId: '1234', mediaItems: mediaItems);
}

SdpMessage parseSdpOfferAnswer(Map<String, dynamic> offer) {
  final sessionId =
      (offer['origin'] as Map<String, dynamic>)['sessionId'] as String;

  final mediaItems = (offer['media'] as List<dynamic>).map((mediaItemObj) {
    final mediaItem = mediaItemObj as Map<String, dynamic>;

    final type = mediaTypeFromString(mediaItem['type'] as String);
    final ufrag = mediaItem['iceUfrag'] as String;
    final pwd = mediaItem['icePwd'] as String;

    // Try to get fingerprint from media first, fallback to offer-level fingerprint
    Map<String, dynamic> fingerprint = {};
    if (mediaItem.containsKey('fingerprint')) {
      fingerprint = mediaItem['fingerprint'] as Map<String, dynamic>;
    } else if (offer.containsKey('fingerprint')) {
      fingerprint = offer['fingerprint'] as Map<String, dynamic>;
    }

    final fingerprintType =
        fingerprintTypeFromString(fingerprint['type'] as String);
    final fingerprintHash = fingerprint['hash'] as String;

    final candidatesList = <SdpMediaCandidate>[];
    if (mediaItem.containsKey('candidates')) {
      for (final candidateObj in mediaItem['candidates'] as List<dynamic>) {
        final candidate = candidateObj as Map<String, dynamic>;
        final candidateType =
            candidateTypeFromString(candidate['type'] as String);
        final transport =
            transportTypeFromString(candidate['transport'] as String);
        final ip = candidate['ip'] as String;
        final port = (candidate['port'] as num).toInt();

        candidatesList.add(SdpMediaCandidate(
          ip: ip,
          port: port,
          type: candidateType,
          transport: transport,
        ));
      }
    }

    return SdpMedia(
      mediaId: 0, // Optional: You can parse 'mid' if needed
      type: type,
      ufrag: ufrag,
      pwd: pwd,
      fingerprintType: fingerprintType,
      fingerprintHash: fingerprintHash,
      candidates: candidatesList,
      payloads: '', // Optional: you can extract these too if present
      rtpCodec: '',
    );
  }).toList();

  final message = SdpMessage(
    sessionId: sessionId,
    mediaItems: mediaItems,
  );

  print('It seems the client has received our SDP Offer, processed it, '
      'accepted it, initialized its media devices, started its UDP listener, '
      'and sent us this SDP Answer.\n'
      'In this project, we don’t use the client’s candidates because we only implement '
      'receiver functionality — no media is sent back :)');

  print('Processing Incoming SDP:\n$message\n');
  return message;
}

MediaType mediaTypeFromString(String type) {
  return MediaType.values.firstWhere((e) => e.name == type.toLowerCase());
}

CandidateType candidateTypeFromString(String type) {
  return CandidateType.values.firstWhere((e) => e.name == type.toLowerCase());
}

TransportType transportTypeFromString(String type) {
  return TransportType.values.firstWhere((e) => e.name == type.toLowerCase());
}

FingerprintType fingerprintTypeFromString(String type) {
  // Normalize the dash if needed (e.g., "sha-256" -> "sha256")
  final normalized = type.replaceAll('-', '').toLowerCase();
  return FingerprintType.values.firstWhere((e) => e.name == normalized);
}

extension SdpMediaCandidateSerialization on SdpMediaCandidate {
  Map<String, dynamic> toMap() {
    return {
      'ip': ip,
      'port': port,
      'type': type.name,
      'transport': transport.name,
    };
  }
}

extension SdpMediaSerialization on SdpMedia {
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'iceUfrag': ufrag,
      'icePwd': pwd,
      'fingerprint': {
        'type': fingerprintType.name,
        'hash': fingerprintHash,
      },
      'candidates': candidates.map((c) => c.toMap()).toList(),
      'payloads': payloads,
      'rtpCodec': rtpCodec,
      'mid': mediaId.toString(),
    };
  }
}

extension SdpMessageSerialization on SdpMessage {
  Map<String, dynamic> toMap() {
    return {
      'origin': {
        'sessionId': sessionId,
      },
      'media': mediaItems.map((m) => m.toMap()).toList(),
      if (mediaItems.isNotEmpty)
        'fingerprint': {
          'type': mediaItems.first.fingerprintType.name,
          'hash': mediaItems.first.fingerprintHash,
        },
    };
  }
}

void main() {
  const chromeOfferSdp = {
    "type": "offer",
    "sdp":
        "v=0\r\no=- 4215775240449105457 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0 1\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS 160d6347-77ea-40b8-aded-2b586daf50ea\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\na=ice-ufrag:yxYb\r\na=ice-pwd:05iMxO9GujD2fUWXSoi0ByNd\r\na=ice-options:trickle\r\na=fingerprint:sha-256 B4:C4:F9:49:A6:5A:11:49:3E:66:BD:1F:B3:43:E3:54:A9:3E:1D:11:71:5B:E0:4D:5F:F4:BC:D2:19:3B:84:E5\r\na=setup:actpass\r\na=mid:0\r\na=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\na=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\na=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\na=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\na=sendrecv\r\na=msid:160d6347-77ea-40b8-aded-2b586daf50ea ebe4768c-cec1-4e71-bc80-099c1e6c1f10\r\na=rtcp-mux\r\na=rtpmap:111 opus/48000/2\r\na=rtcp-fb:111 transport-cc\r\na=fmtp:111 minptime=10;useinbandfec=1\r\na=rtpmap:63 red/48000/2\r\na=fmtp:63 111/111\r\na=rtpmap:9 G722/8000\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:13 CN/8000\r\na=rtpmap:110 telephone-event/48000\r\na=rtpmap:126 telephone-event/8000\r\na=ssrc:3485940486 cname:Dm9nmXDg4q8eNPqz\r\na=ssrc:3485940486 msid:160d6347-77ea-40b8-aded-2b586daf50ea ebe4768c-cec1-4e71-bc80-099c1e6c1f10\r\nm=video 9 UDP/TLS/RTP/SAVPF 96 97 102 103 104 105 106 107 108 109 127 125 39 40 98 99 100 101 112 113 114 115 116\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\na=ice-ufrag:yxYb\r\na=ice-pwd:05iMxO9GujD2fUWXSoi0ByNd\r\na=ice-options:trickle\r\na=fingerprint:sha-256 B4:C4:F9:49:A6:5A:11:49:3E:66:BD:1F:B3:43:E3:54:A9:3E:1D:11:71:5B:E0:4D:5F:F4:BC:D2:19:3B:84:E5\r\na=setup:actpass\r\na=mid:1\r\na=extmap:14 urn:ietf:params:rtp-hdrext:toffset\r\na=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\na=extmap:13 urn:3gpp:video-orientation\r\na=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\na=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\na=extmap:6 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\na=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\na=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\na=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\na=extmap:10 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\na=extmap:11 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\na=sendrecv\r\na=msid:160d6347-77ea-40b8-aded-2b586daf50ea f6d17d02-83e5-4023-9729-8fbe26711952\r\na=rtcp-mux\r\na=rtcp-rsize\r\na=rtpmap:96 VP8/90000\r\na=rtcp-fb:96 goog-remb\r\na=rtcp-fb:96 transport-cc\r\na=rtcp-fb:96 ccm fir\r\na=rtcp-fb:96 nack\r\na=rtcp-fb:96 nack pli\r\na=rtpmap:97 rtx/90000\r\na=fmtp:97 apt=96\r\na=rtpmap:102 H264/90000\r\na=rtcp-fb:102 goog-remb\r\na=rtcp-fb:102 transport-cc\r\na=rtcp-fb:102 ccm fir\r\na=rtcp-fb:102 nack\r\na=rtcp-fb:102 nack pli\r\na=fmtp:102 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f\r\na=rtpmap:103 rtx/90000\r\na=fmtp:103 apt=102\r\na=rtpmap:104 H264/90000\r\na=rtcp-fb:104 goog-remb\r\na=rtcp-fb:104 transport-cc\r\na=rtcp-fb:104 ccm fir\r\na=rtcp-fb:104 nack\r\na=rtcp-fb:104 nack pli\r\na=fmtp:104 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42001f\r\na=rtpmap:105 rtx/90000\r\na=fmtp:105 apt=104\r\na=rtpmap:106 H264/90000\r\na=rtcp-fb:106 goog-remb\r\na=rtcp-fb:106 transport-cc\r\na=rtcp-fb:106 ccm fir\r\na=rtcp-fb:106 nack\r\na=rtcp-fb:106 nack pli\r\na=fmtp:106 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\na=rtpmap:107 rtx/90000\r\na=fmtp:107 apt=106\r\na=rtpmap:108 H264/90000\r\na=rtcp-fb:108 goog-remb\r\na=rtcp-fb:108 transport-cc\r\na=rtcp-fb:108 ccm fir\r\na=rtcp-fb:108 nack\r\na=rtcp-fb:108 nack pli\r\na=fmtp:108 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42e01f\r\na=rtpmap:109 rtx/90000\r\na=fmtp:109 apt=108\r\na=rtpmap:127 H264/90000\r\na=rtcp-fb:127 goog-remb\r\na=rtcp-fb:127 transport-cc\r\na=rtcp-fb:127 ccm fir\r\na=rtcp-fb:127 nack\r\na=rtcp-fb:127 nack pli\r\na=fmtp:127 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=4d001f\r\na=rtpmap:125 rtx/90000\r\na=fmtp:125 apt=127\r\na=rtpmap:39 H264/90000\r\na=rtcp-fb:39 goog-remb\r\na=rtcp-fb:39 transport-cc\r\na=rtcp-fb:39 ccm fir\r\na=rtcp-fb:39 nack\r\na=rtcp-fb:39 nack pli\r\na=fmtp:39 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=4d001f\r\na=rtpmap:40 rtx/90000\r\na=fmtp:40 apt=39\r\na=rtpmap:98 VP9/90000\r\na=rtcp-fb:98 goog-remb\r\na=rtcp-fb:98 transport-cc\r\na=rtcp-fb:98 ccm fir\r\na=rtcp-fb:98 nack\r\na=rtcp-fb:98 nack pli\r\na=fmtp:98 profile-id=0\r\na=rtpmap:99 rtx/90000\r\na=fmtp:99 apt=98\r\na=rtpmap:100 VP9/90000\r\na=rtcp-fb:100 goog-remb\r\na=rtcp-fb:100 transport-cc\r\na=rtcp-fb:100 ccm fir\r\na=rtcp-fb:100 nack\r\na=rtcp-fb:100 nack pli\r\na=fmtp:100 profile-id=2\r\na=rtpmap:101 rtx/90000\r\na=fmtp:101 apt=100\r\na=rtpmap:112 H264/90000\r\na=rtcp-fb:112 goog-remb\r\na=rtcp-fb:112 transport-cc\r\na=rtcp-fb:112 ccm fir\r\na=rtcp-fb:112 nack\r\na=rtcp-fb:112 nack pli\r\na=fmtp:112 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=64001f\r\na=rtpmap:113 rtx/90000\r\na=fmtp:113 apt=112\r\na=rtpmap:114 red/90000\r\na=rtpmap:115 rtx/90000\r\na=fmtp:115 apt=114\r\na=rtpmap:116 ulpfec/90000\r\na=ssrc-group:FID 4176833956 4153795228\r\na=ssrc:4176833956 cname:Dm9nmXDg4q8eNPqz\r\na=ssrc:4176833956 msid:160d6347-77ea-40b8-aded-2b586daf50ea f6d17d02-83e5-4023-9729-8fbe26711952\r\na=ssrc:4153795228 cname:Dm9nmXDg4q8eNPqz\r\na=ssrc:4153795228 msid:160d6347-77ea-40b8-aded-2b586daf50ea f6d17d02-83e5-4023-9729-8fbe26711952\r\n"
  };
  const chromeAnswerSdp = {
    "type": "answer",
    "sdp":
        "v=0\r\no=- 2875481597283948546 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0 1\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\na=ice-ufrag:zbhr\r\na=ice-pwd:pzhairRs+AhjQigDx9V5mu9s\r\na=ice-options:trickle\r\na=fingerprint:sha-256 EA:70:3E:9F:C4:CC:85:E9:68:4D:C4:82:0F:15:63:79:0B:8C:BE:FB:B2:47:06:BA:D0:E7:3A:63:8C:EB:C6:1E\r\na=setup:active\r\na=mid:0\r\na=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\na=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\na=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\na=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\na=recvonly\r\na=rtcp-mux\r\na=rtpmap:111 opus/48000/2\r\na=rtcp-fb:111 transport-cc\r\na=fmtp:111 minptime=10;useinbandfec=1\r\na=rtpmap:63 red/48000/2\r\na=fmtp:63 111/111\r\na=rtpmap:9 G722/8000\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:13 CN/8000\r\na=rtpmap:110 telephone-event/48000\r\na=rtpmap:126 telephone-event/8000\r\nm=video 9 UDP/TLS/RTP/SAVPF 96 97 102 103 104 105 106 107 108 109 127 125 39 40 98 99 100 101 112 113 114 115 116\r\nc=IN IP4 0.0.0.0\r\na=rtcp:9 IN IP4 0.0.0.0\r\na=ice-ufrag:zbhr\r\na=ice-pwd:pzhairRs+AhjQigDx9V5mu9s\r\na=ice-options:trickle\r\na=fingerprint:sha-256 EA:70:3E:9F:C4:CC:85:E9:68:4D:C4:82:0F:15:63:79:0B:8C:BE:FB:B2:47:06:BA:D0:E7:3A:63:8C:EB:C6:1E\r\na=setup:active\r\na=mid:1\r\na=extmap:14 urn:ietf:params:rtp-hdrext:toffset\r\na=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\na=extmap:13 urn:3gpp:video-orientation\r\na=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\na=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\na=extmap:6 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\na=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\na=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\na=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\na=extmap:10 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\na=extmap:11 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\na=recvonly\r\na=rtcp-mux\r\na=rtcp-rsize\r\na=rtpmap:96 VP8/90000\r\na=rtcp-fb:96 goog-remb\r\na=rtcp-fb:96 transport-cc\r\na=rtcp-fb:96 ccm fir\r\na=rtcp-fb:96 nack\r\na=rtcp-fb:96 nack pli\r\na=rtpmap:97 rtx/90000\r\na=fmtp:97 apt=96\r\na=rtpmap:102 H264/90000\r\na=rtcp-fb:102 goog-remb\r\na=rtcp-fb:102 transport-cc\r\na=rtcp-fb:102 ccm fir\r\na=rtcp-fb:102 nack\r\na=rtcp-fb:102 nack pli\r\na=fmtp:102 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f\r\na=rtpmap:103 rtx/90000\r\na=fmtp:103 apt=102\r\na=rtpmap:104 H264/90000\r\na=rtcp-fb:104 goog-remb\r\na=rtcp-fb:104 transport-cc\r\na=rtcp-fb:104 ccm fir\r\na=rtcp-fb:104 nack\r\na=rtcp-fb:104 nack pli\r\na=fmtp:104 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42001f\r\na=rtpmap:105 rtx/90000\r\na=fmtp:105 apt=104\r\na=rtpmap:106 H264/90000\r\na=rtcp-fb:106 goog-remb\r\na=rtcp-fb:106 transport-cc\r\na=rtcp-fb:106 ccm fir\r\na=rtcp-fb:106 nack\r\na=rtcp-fb:106 nack pli\r\na=fmtp:106 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\na=rtpmap:107 rtx/90000\r\na=fmtp:107 apt=106\r\na=rtpmap:108 H264/90000\r\na=rtcp-fb:108 goog-remb\r\na=rtcp-fb:108 transport-cc\r\na=rtcp-fb:108 ccm fir\r\na=rtcp-fb:108 nack\r\na=rtcp-fb:108 nack pli\r\na=fmtp:108 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42e01f\r\na=rtpmap:109 rtx/90000\r\na=fmtp:109 apt=108\r\na=rtpmap:127 H264/90000\r\na=rtcp-fb:127 goog-remb\r\na=rtcp-fb:127 transport-cc\r\na=rtcp-fb:127 ccm fir\r\na=rtcp-fb:127 nack\r\na=rtcp-fb:127 nack pli\r\na=fmtp:127 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=4d001f\r\na=rtpmap:125 rtx/90000\r\na=fmtp:125 apt=127\r\na=rtpmap:39 H264/90000\r\na=rtcp-fb:39 goog-remb\r\na=rtcp-fb:39 transport-cc\r\na=rtcp-fb:39 ccm fir\r\na=rtcp-fb:39 nack\r\na=rtcp-fb:39 nack pli\r\na=fmtp:39 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=4d001f\r\na=rtpmap:40 rtx/90000\r\na=fmtp:40 apt=39\r\na=rtpmap:98 VP9/90000\r\na=rtcp-fb:98 goog-remb\r\na=rtcp-fb:98 transport-cc\r\na=rtcp-fb:98 ccm fir\r\na=rtcp-fb:98 nack\r\na=rtcp-fb:98 nack pli\r\na=fmtp:98 profile-id=0\r\na=rtpmap:99 rtx/90000\r\na=fmtp:99 apt=98\r\na=rtpmap:100 VP9/90000\r\na=rtcp-fb:100 goog-remb\r\na=rtcp-fb:100 transport-cc\r\na=rtcp-fb:100 ccm fir\r\na=rtcp-fb:100 nack\r\na=rtcp-fb:100 nack pli\r\na=fmtp:100 profile-id=2\r\na=rtpmap:101 rtx/90000\r\na=fmtp:101 apt=100\r\na=rtpmap:112 H264/90000\r\na=rtcp-fb:112 goog-remb\r\na=rtcp-fb:112 transport-cc\r\na=rtcp-fb:112 ccm fir\r\na=rtcp-fb:112 nack\r\na=rtcp-fb:112 nack pli\r\na=fmtp:112 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=64001f\r\na=rtpmap:113 rtx/90000\r\na=fmtp:113 apt=112\r\na=rtpmap:114 red/90000\r\na=rtpmap:115 rtx/90000\r\na=fmtp:115 apt=114\r\na=rtpmap:116 ulpfec/90000\r\n"
  };

  const simpleTest = [
    {"offer": chromeOfferSdp, "answer": chromeAnswerSdp}
  ];

  final sdpOffer = parse(chromeOfferSdp['sdp'] as String);
  print("Parsed: $sdpOffer");

  // parseSdpOfferAnswer(sdpOffer);
}
