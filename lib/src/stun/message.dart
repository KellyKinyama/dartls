import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:async';
// import 'package:crc32/crc32.dart';
// import 'package:cryptography/cryptography.dart';
import 'package:collection/equality.dart';
import 'package:crypto/crypto.dart' show Hmac, sha1, sha256;

// import 'package:cryptography/cryptography.dart';

import 'crc32.dart'; // Import the crc32 package

// Constants
const int magicCookie = 0x2112A442;
const int messageHeaderSize = 20;
const int transactionIDSize = 12; // 96 bit
const int fingerprintSize = 4;
const int fingerprintXorMask = 0x5354554e;

// Utility function to calculate CRC32 checksum
// int calculateCRC32(Uint8List data) {
//   return crc32(data) ^ fingerprintXorMask;
// }

Uint8List hmacSha1(Uint8List key, Uint8List data) {
  var hmac = Hmac(sha1, key);
  return Uint8List.fromList(hmac.convert(data).bytes);
}

// HMAC calculation
Uint8List calculateHmac(Uint8List binMsg, String pwd) {
  final key = utf8.encode(pwd);
  return hmacSha1(key, binMsg);
}

// Fingerprint calculation
Uint8List calculateFingerprint(Uint8List binMsg) {
  final result = ByteData(4);
  final checksum = calculateCRC32(binMsg);
  result.setUint32(0, checksum);
  return result.buffer.asUint8List();
}

class StunMessage {
  int messageType;
  List<int> transactionID;
  Map<int, StunAttribute> attributes = {};
  List<int> rawMessage = [];

  StunMessage(this.messageType, this.transactionID);

  String toString() {
    final transactionIDStr = base64Encode(transactionID);
    final attrsStr = attributes.values.map((a) => a.toString()).join(' ');
    return '$messageType id=$transactionIDStr attrs=$attrsStr';
  }

  // Encode the message to bytes
  List<int> encode(String pwd) {
    final encodedAttrs = <int>[];
    attributes.forEach((_, attr) {
      encodedAttrs.addAll(attr.encode());
    });

    final result = List<int>.filled(messageHeaderSize + encodedAttrs.length, 0);

    result.setRange(
        0, 2, Uint16List.fromList([messageType]).buffer.asUint8List());
    result.setRange(
        2, 4, Uint16List.fromList([encodedAttrs.length]).buffer.asUint8List());
    result.setRange(
        4, 8, Uint32List.fromList([magicCookie]).buffer.asUint8List());
    result.setRange(8, 20, transactionID);

    result.setAll(20, encodedAttrs);
    result.addAll(postEncode(result, encodedAttrs.length, pwd));

    return result;
  }

  // Post-encode the message with HMAC and Fingerprint
  List<int> postEncode(List<int> encodedMessage, int dataLength, String pwd) {
    final hmacAttr = StunAttribute(
        0x0008, calculateHmac(Uint8List.fromList(encodedMessage), pwd));
    encodedMessage.addAll(hmacAttr.encode());

    final fingerprintAttr = StunAttribute(
        0x0009, calculateFingerprint(Uint8List.fromList(encodedMessage)));
    encodedMessage.addAll(fingerprintAttr.encode());

    final length =
        dataLength + hmacAttr.encode().length + fingerprintAttr.encode().length;
    final result = List<int>.from(encodedMessage);
    result.setRange(2, 4, Uint16List.fromList([length]).buffer.asUint8List());
    return result;
  }

  // Decode STUN message
  static StunMessage decode(List<int> buffer, int offset, int arrayLen) {
    if (arrayLen < messageHeaderSize) {
      throw Exception('Incomplete STUN frame');
    }

    int messageType =
        Uint16List.fromList(buffer.sublist(offset, offset + 2)).first;
    offset += 2;

    int messageLength =
        Uint16List.fromList(buffer.sublist(offset, offset + 2)).first;
    offset += 2;

    offset += 4; // Skip magic cookie
    List<int> transactionID =
        buffer.sublist(offset, offset + transactionIDSize);
    offset += transactionIDSize;

    var message = StunMessage(messageType, transactionID);
    message.rawMessage = buffer.sublist(0, arrayLen);

    while (offset - messageHeaderSize < messageLength) {
      var attr = StunAttribute.decode(buffer, offset);
      message.attributes[attr.type] = attr;
      offset += attr.length;
    }

    return message;
  }

  void validate(String ufrag, String pwd) {
    final usernameAttr = attributes[0x0006]; // UserName Attribute
    if (usernameAttr != null) {
      final username = utf8.decode(usernameAttr.value).split(':')[0];
      if (username != ufrag) {
        throw Exception('Invalid Username');
      }
    }

    final hmacAttr = attributes[0x0008]; // MessageIntegrity Attribute
    if (hmacAttr != null) {
      final calculatedHmac = calculateHmac(Uint8List.fromList(rawMessage), pwd);
      if (!ListEquality().equals(calculatedHmac, hmacAttr.value)) {
        throw Exception('Invalid Message Integrity');
      }
    }

    final fingerprintAttr = attributes[0x0009]; // Fingerprint Attribute
    if (fingerprintAttr != null) {
      final calculatedFingerprint =
          calculateFingerprint(Uint8List.fromList(rawMessage));
      if (!ListEquality()
          .equals(calculatedFingerprint, fingerprintAttr.value)) {
        throw Exception('Invalid Fingerprint');
      }
    }
  }
}

class StunAttribute {
  int type;
  List<int> value;

  StunAttribute(this.type, this.value);

  // Encode the attribute
  List<int> encode() {
    final length = value.length;
    final result = ByteData(4 + length);
    result.setUint16(0, type);
    result.setUint16(2, length);
    result.buffer.asUint8List().setRange(4, 4 + length, value);
    return result.buffer.asUint8List();
  }

  // Decode the attribute
  static StunAttribute decode(List<int> buffer, int offset) {
    final type = Uint16List.fromList(buffer.sublist(offset, offset + 2)).first;
    final length =
        Uint16List.fromList(buffer.sublist(offset + 2, offset + 4)).first;
    final value = buffer.sublist(offset + 4, offset + 4 + length);
    return StunAttribute(type, value);
  }

  @override
  String toString() {
    return 'Type: $type, Value: ${utf8.decode(value)}';
  }

  int get length => 4 + value.length;
}

// Sample STUN message decoding and encoding
void main() async {
  final messageType = 0x0001; // Binding Request
  final transactionID =
      List<int>.generate(transactionIDSize, (i) => Random().nextInt(256));

  final message = StunMessage(messageType, transactionID);

  final encodedMessage = message.encode('password');
  print('Encoded Message: ${base64Encode(Uint8List.fromList(encodedMessage))}');

  final decodedMessage = StunMessage.decode(
      Uint8List.fromList(encodedMessage), 0, encodedMessage.length);
  print('Decoded Message: ${decodedMessage.toString()}');
}
