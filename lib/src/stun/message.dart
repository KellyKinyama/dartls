// package stun

// import (
// 	"bytes"
// 	"crypto/hmac"
// 	"crypto/sha1"
// 	"encoding/base64"
// 	"encoding/binary"
// 	"errors"
// 	"fmt"
// 	"hash/crc32"
// 	"strings"

// 	"github.com/adalkiran/webrtc-nuts-and-bolts/src/config"
// )

// var (
// 	//errInvalidTURNFrame    = errors.New("data is not a valid TURN frame, no STUN or ChannelData found")
// 	errIncompleteTURNFrame = errors.New("data contains incomplete STUN or TURN frame")
// )

import 'dart:convert';
import 'dart:typed_data';

import 'attribute.dart';
import 'attribute_type.dart';
import 'message_type.dart';

class Message  {
	MessageType   messageType;
	Uint8List TransactionID =Uint8List(TransactionIDSize) ;
	Map<AttributeType,Attribute> attributes; //   map[AttributeType]Attribute
	Uint8List rawMessage;//    []byte
}

// const (
const	magicCookie       = 0x2112A442;
const		messageHeaderSize = 20;

const		TransactionIDSize = 12; // 96 bit

const		stunHeaderSize = 20;

const		hmacSignatureSize = 20;

const		fingerprintSize = 4;

const		fingerprintXorMask = 0x5354554e;
// )

// func (m Message) String() string {
// 	transactionIDStr := base64.StdEncoding.EncodeToString(m.TransactionID[:])
// 	attrsStr := ""
// 	for _, a := range m.Attributes {
// 		attrsStr += fmt.Sprintf("%s ", strings.ReplaceAll(a.String(), "\r", " "))
// 	}
// 	return fmt.Sprintf("%s id=%s attrs=%s", m.MessageType, transactionIDStr, attrsStr)
// }

bool isMessage(Uint8List buf, int offset, int arrayLen)  {
	return arrayLen >= messageHeaderSize && ByteData.sublistView(buf).getUint32(offset+4) == magicCookie;
}

Message DecodeMessage(Uint8List buf, int offset, int arrayLen){
	if (arrayLen < stunHeaderSize) {
		throw "errIncompleteTURNFrame";
	}

  ByteData reader =ByteData.sublistView(buf);

	final offsetBackup = offset;

	final messageType = reader.getUint16(offset);

	offset += 2;

	final messageLength = reader.getUint16(offset);

	offset += 2;

	// Adding message cookie length
	offset += 4;

	// result := new(Message)

	final RawMessage = buf.sublist(offsetBackup,offsetBackup+arrayLen);

	final MessageType = decodeMessageType(messageType);

	// copy(result.TransactionID[:], buf[offset:offset+TransactionIDSize])
  final TransactionID=buf.sublist(offset,offset+TransactionIDSize)

	offset += TransactionIDSize;
	Map<AttributeType,Attribute> Attributes = {}
	for (offset-stunHeaderSize < messageLength) {
		final decodedAttr = decodeAttribute(buf, offset, arrayLen);
		// if err != nil {
		// 	return nil, err
		// }
		fSetAttribute(*decodedAttr)
		offset += decodedAttr.GetRawFullLength();

		if (decodedAttr.getRawDataLength()%4 > 0) {
			offset += 4 - decodedAttr.getRawDataLength()%4;
		}
	}
	return result, nil
}

Uint8List calculateHmac(Uint8List binMsg, String pwd)  {
	final key = utf8.encode(pwd);
	final messageLength = (binMsg.length + attributeHeaderSize + hmacSignatureSize - messageHeaderSize);
	ByteData.sublistView(binMsg).setUint16(2, messageLength);
	mac := hmac.New(sha1.New, key)
	mac.Write(binMsg)
	return mac.Sum(nil)
}

Uint8List calculateFingerprint(Uint8List binMsg )  {
	final result = Uint8List( 4);
	final messageLength = ((binMsg.length) + attributeHeaderSize + fingerprintSize - messageHeaderSize);
	ByteData.sublistView(binMsg).setUint16(2, messageLength);

	binary.BigEndian.PutUint32(result, crc32.ChecksumIEEE(binMsg)^fingerprintXorMask)
	return result;
}

func (m *Message) preEncode() {
	// https://github.com/jitsi/ice4j/blob/32a8aadae8fde9b94081f8d002b6fda3490c20dc/src/main/java/org/ice4j/message/Message.java#L1015
	delete(m.Attributes, AttrMessageIntegrity)
	delete(m.Attributes, AttrFingerprint)
	m.Attributes[AttrSoftware] = *createAttrSoftware(config.Val.Server.SoftwareName)
}
func (m *Message) postEncode(encodedMessage []byte, dataLength int, pwd string) []byte {
	// https://github.com/jitsi/ice4j/blob/32a8aadae8fde9b94081f8d002b6fda3490c20dc/src/main/java/org/ice4j/message/Message.java#L1015
	messageIntegrityAttr := &Attribute{
		AttributeType: AttrMessageIntegrity,
		Value:         calculateHmac(encodedMessage, pwd),
	}
	encodedMessageIntegrity := messageIntegrityAttr.Encode()
	encodedMessage = append(encodedMessage, encodedMessageIntegrity...)

	messageFingerprint := &Attribute{
		AttributeType: AttrFingerprint,
		Value:         calculateFingerprint(encodedMessage),
	}
	encodedFingerprint := messageFingerprint.Encode()

	encodedMessage = append(encodedMessage, encodedFingerprint...)

	binary.BigEndian.PutUint16(encodedMessage[2:4], uint16(dataLength+len(encodedMessageIntegrity)+len(encodedFingerprint)))

	return encodedMessage
}

func (m *Message) Encode(pwd string) []byte {
	m.preEncode()
	// https://github.com/jitsi/ice4j/blob/311a495b21f38cc2dfcc4f7118dab96b8134aed6/src/main/java/org/ice4j/message/Message.java#L907
	var encodedAttrs []byte
	for _, attr := range m.Attributes {
		encodedAttr := attr.Encode()
		encodedAttrs = append(encodedAttrs, encodedAttr...)
	}

	result := make([]byte, messageHeaderSize+len(encodedAttrs))

	binary.BigEndian.PutUint16(result[0:2], m.MessageType.Encode())
	binary.BigEndian.PutUint16(result[2:4], uint16(len(encodedAttrs)))
	binary.BigEndian.PutUint32(result[4:8], magicCookie)
	copy(result[8:20], m.TransactionID[:])
	copy(result[20:], encodedAttrs)
	result = m.postEncode(result, len(encodedAttrs), pwd)

	return result
}

func (m *Message) Validate(ufrag string, pwd string) {
	// https://github.com/jitsi/ice4j/blob/311a495b21f38cc2dfcc4f7118dab96b8134aed6/src/main/java/org/ice4j/stack/StunStack.java#L1254
	userNameAttr, okUserName := m.Attributes[AttrUserName]
	if okUserName {
		userName := strings.Split(string(userNameAttr.Value), ":")[0]
		if userName != ufrag {
			panic("Message not valid: UserName!")
		}
	}
	if messageIntegrityAttr, ok := m.Attributes[AttrMessageIntegrity]; ok {
		if !okUserName {
			panic("Message not valid: missing username!")
		}
		binMsg := make([]byte, messageIntegrityAttr.OffsetInMessage)
		copy(binMsg, m.RawMessage[0:messageIntegrityAttr.OffsetInMessage])

		calculatedHmac := calculateHmac(binMsg, pwd)
		if !bytes.Equal(calculatedHmac, messageIntegrityAttr.Value) {
			panic(fmt.Sprintf("Message not valid: MESSAGE-INTEGRITY not valid expected: %v , received: %v not compatible!", calculatedHmac, messageIntegrityAttr.Value))
		}
	}

	if fingerprintAttr, ok := m.Attributes[AttrFingerprint]; ok {
		binMsg := make([]byte, fingerprintAttr.OffsetInMessage)
		copy(binMsg, m.RawMessage[0:fingerprintAttr.OffsetInMessage])

		calculatedFingerprint := calculateFingerprint(binMsg)
		if !bytes.Equal(calculatedFingerprint, fingerprintAttr.Value) {
			panic(fmt.Sprintf("Message not valid: FINGERPRINT not valid expected: %v , received: %v not compatible!", calculatedFingerprint, fingerprintAttr.Value))
		}
	}
}

func (m *Message) SetAttribute(attr Attribute) {
	m.Attributes[attr.AttributeType] = attr
}

func createAttrSoftware(software string) *Attribute {
	return &Attribute{
		AttributeType: AttrSoftware,
		Value:         []byte(software),
	}
}

func NewMessage(messageType MessageType, transactionID [12]byte) *Message {
	result := &Message{
		MessageType:   messageType,
		TransactionID: transactionID,
		Attributes:    map[AttributeType]Attribute{},
	}
	return result
}
