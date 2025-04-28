// type MediaType = 'audio' | 'video'
// type CandidateType = 'host'
// type TransportType = 'udp' | 'tcp'
// type FingerprintType = 'sha-256'



import '../agent/server_agent.dart';

enum MediaType { audio("audio")
, video('video') ;

const MediaType(this.value);
final String value;

factory MediaType.fromString(String key) {
    return values.firstWhere((element) => element.value == key);
  }
}

enum CandidateType { host("host") ;

const CandidateType(this.value);
final String value;

factory CandidateType.fromString(String key) {
    return values.firstWhere((element) => element.value == key);
  }
}

enum TransportType { udp("udp"), tcp("tcp");

const TransportType(this.value);
final String value; 

factory TransportType.fromString(String key) {
    return values.firstWhere((element) => element.value == key);
  }
}

enum FingerprintType {
  sha_256('sha-256');

  const FingerprintType(this.value);
final String value; 

factory FingerprintType.fromString(String key) {
    return values.firstWhere((element) => element.value == key);
  }
}

class SdpMessage {
  late String conferenceName;
  late String sessionId;
  late List<SdpMedia> mediaItems;

  
}

class SdpMedia {
  late num mediaId;
  late MediaType type;
  late String ufrag;
  late String pwd;
  late FingerprintType fingerprintType;
  late String fingerprintHash;
  late List<SdpMediaCandidate> candidates;
  late String payloads;
  late String rtpCodec;


  
}

class SdpMediaCandidate {
  late String ip;
  late int port;
  late CandidateType type;
  late TransportType transport;


  
}
// type MediaType string

// const (
// 	MediaTypeVideo MediaType = "video"
// 	MediaTypeAudio MediaType = "audio"
// )

// type CandidateType string

// const (
// 	CandidateTypeHost CandidateType = "host"
// )

// type TransportType string

// const (
// 	TransportTypeUdp TransportType = "udp"
// 	TransportTypeTcp TransportType = "tcp"
// )

// type FingerprintType string

// const (
// 	FingerprintTypeSHA256 FingerprintType = "sha-256"
// )

// type SdpMessage struct {
// 	ConferenceName string
// 	SessionID      string     `json:"sessionId"`
// 	MediaItems     []SdpMedia `json:"mediaItems"`
// }

// type SdpMedia struct {
// 	MediaId         int                 `json:"mediaId"`
// 	Type            MediaType           `json:"type"`
// 	Ufrag           string              `json:"ufrag"`
// 	Pwd             string              `json:"pwd"`
// 	FingerprintType FingerprintType     `json:"fingerprintType"`
// 	FingerprintHash string              `json:"fingerprintHash"`
// 	Candidates      []SdpMediaCandidate `json:"candidates"`
// 	Payloads        string              `json:"payloads"`
// 	RTPCodec        string              `json:"rtpCodec"`
// }

// type SdpMediaCandidate struct {
// 	Ip        string        `json:"ip"`
// 	Port      int           `json:"port"`
// 	Type      CandidateType `json:"type"`
// 	Transport TransportType `json:"transport"`
// }

SdpMessage parseSdpOfferAnswer(Map<String,dynamic> offer) {
	final sdpMessage = SdpMessage();
	// sdpMessage.sessionId = offer["origin"].(map[string]interface{})["sessionId"].(string)

	final mediaItems = offer["media"];

	for (var(_, mediaItemObj) in mediaItems) {
		final sdpMedia = SdpMedia();
		final mediaItem = mediaItemObj;//.(map[string]interface{})
		//mediaId := mediaItem["mid"].(float64)
		sdpMedia.type = MediaType.fromString(mediaItem["type"]);
		List<dynamic> candidates = [];//make([]interface{}, 0)
		if (mediaItem["candidates"] != null) {
			candidates = mediaItem["candidates"];
		}
		sdpMedia.ufrag = mediaItem["iceUfrag"];//.(string)
		sdpMedia.pwd = mediaItem["icePwd"];//.(string)
		//iceOptions := mediaItem["iceOptions"].(string)
		var (fingerprintRaw, ok) = mediaItem["fingerprint"];
		if (!ok) {
			fingerprintRaw = offer["fingerprint"];
		}
		final fingerprint = fingerprintRaw;//.(map[string]interface{})
		sdpMedia.fingerprintType = FingerprintType.fromString(fingerprint["type"]);
		sdpMedia.fingerprintHash = fingerprint["hash"];//.(string)
		final direction = mediaItem["direction"];//.(string)
		for (var(_, candidateObj) in candidates) {
			final sdpMediaCandidate = SdpMediaCandidate();
			final candidate = candidateObj;//.(map[string]interface{})
			//foundation := candidate["foundation"].(float64)
			sdpMediaCandidate.type = CandidateType.fromString(candidate["type"]);
			sdpMediaCandidate.transport = TransportType.fromString(candidate["transport"])
			sdpMediaCandidate.ip = candidate["ip"];
			sdpMediaCandidate.port = int.parse(candidate["port"]);
			sdpMedia.candidates.add(sdpMediaCandidate);// = append(sdpMedia.Candidates, sdpMediaCandidate)
		}
		sdpMessage.mediaItems.add(sdpMedia);// = append(sdpMessage.MediaItems, sdpMedia)
	}
	// logging.Descf(logging.ProtoSDP, "It seems the client has received our SDP Offer, processed it, accepted it, initialized it's media devices (webcam, microphone, etc...), started it's UDP listener, and sent us this SDP Answer. In this project, we don't use the client's candidates, because we has implemented only receiver functionalities, so we don't have any media stream to send :)")
	// logging.Infof(logging.ProtoSDP, "Processing Incoming SDP: %s", sdpMessage)
	// logging.LineSpacer(2)
	return sdpMessage;
}


// SdpMessage generateSdpOffer(ServerAgent iceAgent)  {
// 	final List<SdpMediaCandidate> candidates = [];
// 	for (var agentCandidate in iceAgent.iceCandidates) {
// 		candidates.add(SdpMediaCandidate(
// 			Ip:        agentCandidate.Ip,
// 			Port:      agentCandidate.Port,
// 			Type:      "host",
// 			Transport: TransportTypeUdp,
//     ));
// 	}
// 	final offer = SdpMessage{
// 		SessionID: "1234",
// 		MediaItems: [SdpMedia(
// 			{
// 				MediaId:  0,
// 				Type:     MediaTypeVideo,
// 				Payloads: rtp.PayloadTypeVP8.CodecCodeNumber(), //96
// 				RTPCodec: rtp.PayloadTypeVP8.CodecName(),       //VP8/90000
// 				Ufrag:    iceAgent.Ufrag,
// 				Pwd:      iceAgent.Pwd,
// 				/*
// 					https://webrtcforthecurious.com/docs/04-securing/
// 					Certificate #
// 					Certificate contains the certificate for the Client or Server.
// 					This is used to uniquely identify who we were communicating with.
// 					After the handshake is over we will make sure this certificate
// 					when hashed matches the fingerprint in the SessionDescription.
// 				*/
// 				FingerprintType: FingerprintTypeSHA256,
// 				FingerprintHash: iceAgent.FingerprintHash,
// 				Candidates:      candidates,
// 			},
// 		)],
// 	}
// 	if (config.Val.Server.RequestAudio) {
// 		offer.MediaItems = append(offer.MediaItems, SdpMedia{
// 			MediaId:  1,
// 			Type:     MediaTypeAudio,
// 			Payloads: rtp.PayloadTypeOpus.CodecCodeNumber(), //109
// 			RTPCodec: rtp.PayloadTypeOpus.CodecName(),       //OPUS/48000/2
// 			Ufrag:    iceAgent.Ufrag,
// 			Pwd:      iceAgent.Pwd,
// 			/*
// 				https://webrtcforthecurious.com/docs/04-securing/
// 				Certificate #
// 				Certificate contains the certificate for the Client or Server.
// 				This is used to uniquely identify who we were communicating with.
// 				After the handshake is over we will make sure this certificate
// 				when hashed matches the fingerprint in the SessionDescription.
// 			*/
// 			FingerprintType: FingerprintType.sha_256,
// 			FingerprintHash: iceAgent.FingerprintHash,
// 			Candidates:      candidates,
// 		})
// 	}
// 	return offer;
// }







