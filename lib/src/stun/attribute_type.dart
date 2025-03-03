

typedef AttributeType =int;

class AttributeTypeDef {
	String name;
  AttributeTypeDef(this.name);
}

// func (at AttributeType) String() string {
// 	attributeTypeDef, ok := attributeTypeMap[at]
// 	if !ok {
// 		// Just return hex representation of unknown attribute type.
// 		return fmt.Sprintf("0x%x", uint16(at))
// 	}
// 	return attributeTypeDef.Name
// }

// const (
	// STUN attributes:

const	AttrMappedAddress      = 0x0001;
const	AttrResponseAddress    = 0x0002;
const	AttrChangeRequest      = 0x0003;
const	AttrSourceAddress      = 0x0004;
const	AttrChangedAddress     = 0x0005;
const	AttrUserName           = 0x0006;
const	AttrPassword           = 0x0007;
const	AttrMessageIntegrity   = 0x0008;
const	AttrErrorCode          = 0x0009;
const	AttrUnknownAttributes  = 0x000a;
const	AttrReflectedFrom      = 0x000b;
const	AttrRealm              = 0x0014;
const	AttrNonce              = 0x0015;
const	AttrXorMappedAddress   = 0x0020;
const	AttrSoftware           = 0x8022;
const	AttrAlternameServer    = 0x8023;
const	AttrFingerprint        = 0x8028;

	// TURN attributes:
const	AttrChannelNumber       = 0x000C;
const	AttrLifetime            = 0x000D;
const	AttrXorPeerAdddress     = 0x0012;
const	AttrData                = 0x0013;
const	AttrXorRelayedAddress   = 0x0016;
const	AttrEvenPort            = 0x0018;
const	AttrRequestedPort       = 0x0019;
const	AttrDontFragment        = 0x001A;
const	AttrReservationRequest  = 0x0022;

	// ICE attributes:
const	AttrPriority        = 0x0024;
const	AttrUseCandidate    = 0x0025;
const	AttrIceControlled   = 0x8029;
const	AttrIceControlling  = 0x802A;
// )

Map<AttributeType,AttributeTypeDef> attributeTypeMap = {
	// STUN attributes:
	AttrMappedAddress:     AttributeTypeDef("MAPPED-ADDRESS"),
	AttrResponseAddress:   AttributeTypeDef("RESPONSE-ADDRESS"),
	AttrChangeRequest:     AttributeTypeDef("CHANGE-REQUEST"),
	AttrSourceAddress:     AttributeTypeDef("SOURCE-ADDRESS"),
	AttrChangedAddress:    AttributeTypeDef("CHANGED-ADDRESS"),
	AttrUserName:          AttributeTypeDef("USERNAME"),
	AttrPassword:          AttributeTypeDef("PASSWORD"),
	AttrMessageIntegrity:  AttributeTypeDef("MESSAGE-INTEGRITY"),
	AttrErrorCode:         AttributeTypeDef("ERROR-CODE"),
	AttrUnknownAttributes: AttributeTypeDef("UNKNOWN-ATTRIBUTE"),
	AttrReflectedFrom:     AttributeTypeDef("REFLECTED-FROM"),
	AttrRealm:             AttributeTypeDef("REALM"),
	AttrNonce:             AttributeTypeDef("NONCE"),
	AttrXorMappedAddress:  AttributeTypeDef("XOR-MAPPED-ADDRES"),
	AttrSoftware:          AttributeTypeDef("SOFTWARE"),
	AttrAlternameServer:   AttributeTypeDef("ALTERNATE-SERVER"),
	AttrFingerprint:       AttributeTypeDef("FINGERPRINT"),

	// TURN attributes:
	AttrChannelNumber:      AttributeTypeDef("CHANNEL-NUMBER"),
	AttrLifetime:           AttributeTypeDef("LIFETIME"),
	AttrXorPeerAdddress:    AttributeTypeDef("XOR-PEER-ADDRESS"),
	AttrData:               AttributeTypeDef("DATA"),
	AttrXorRelayedAddress:  AttributeTypeDef("XOR-RELAYED-ADDRESS"),
	AttrEvenPort:           AttributeTypeDef("EVEN-PORT"),
	AttrRequestedPort:      AttributeTypeDef("REQUESTED-TRANSPORT"),
	AttrDontFragment:       AttributeTypeDef("DONT-FRAGMENT"),
	AttrReservationRequest: AttributeTypeDef("RESERVATION-TOKEN"),

	// ICE attributes:
	AttrPriority:       AttributeTypeDef("PRIORITY"),
	AttrUseCandidate:   AttributeTypeDef("USE-CANDIDATE"),
	AttrIceControlled:  AttributeTypeDef("ICE-CONTROLLED"),
	AttrIceControlling: AttributeTypeDef("ICE-CONTROLLING"),
};
