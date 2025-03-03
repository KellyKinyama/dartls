import 'dart:io';
import 'dart:typed_data';

import 'attribute.dart';
import 'attribute_type.dart';
import 'message.dart';

typedef IPFamily = int;

// const (
const IPFamilyIPv4 = 0x01;
const IPFamilyIPV6 = 0x02;
// )

class MappedAddress {
  IPFamily ipFamily;
  InternetAddress ip;
  int port; // uint16

  MappedAddress(this.ipFamily, this.ip, this.port);
}

Attribute createAttrXorMappedAddress(
    Uint8List transactionID, InternetAddress addr, int addrPort) {
  // https://github.com/jitsi/ice4j/blob/311a495b21f38cc2dfcc4f7118dab96b8134aed6/src/main/java/org/ice4j/attribute/XorMappedAddressAttribute.java#L131
  final xorMask = Uint8List(16);
  ByteData writer = ByteData.sublistView(xorMask);
  writer.setUint32(0, magicCookie);
  // copy(xorMask[4:], transactionID)
  xorMask.setRange(4, 16, transactionID);
  //addressBytes := ms.Addr.IP
  final portModifier =
      (((xorMask[0]) << 8) & 0x0000FF00) | ((xorMask[1]) & 0x000000FF);
  final addressBytes = addr.rawAddress;
  // copy(addressBytes, addr.IP.To4())
  final port = addrPort ^ portModifier;
  for (int i in addressBytes) {
    addressBytes[i] ^= xorMask[i];
  }

  final value = Uint8List(8);
  writer = ByteData.sublistView(value);

  value[1] = IPFamilyIPv4;
  writer.setUint16(2, port);
  // copy(value[4:8], addressBytes)
  value.setRange(4, 8, addressBytes);
  return Attribute(AttrXorMappedAddress, value, 0);
  // 	AttributeType: AttrXorMappedAddress,
  // 	Value:         value,
  // }
}

MappedAddress DecodeAttrXorMappedAddress(
    Attribute attr, Uint8List transactionID) {
  final xorMask = Uint8List(16);
  ByteData writer = ByteData.sublistView(xorMask);
  writer.setUint32(0, magicCookie);
  // copy(xorMask[4:], transactionID)
  xorMask.setRange(4, 16, transactionID);

  Uint8List xorIP = Uint8List(16);
  for (int i = 0; i < attr.value.length - 4; i++) {
    xorIP[i] = attr.value[i + 4] ^ xorMask[i];
  }
  final family = attr.value[1];
  final port = ByteData.sublistView(attr.value).getUint16(2);
  // Truncate if IPv4, otherwise net.IP sometimes renders it as an IPv6 address.
  if (family == IPFamilyIPv4) {
    xorIP = xorIP.sublist(0, 4);
  }
  final x = ByteData.sublistView(xorMask).getUint16(0);
  return MappedAddress(
      family,
      InternetAddress.fromRawAddress(xorIP, type: InternetAddressType.IPv4),
      port ^ x);
}

// func CreateAttrUserName(userName string) *Attribute {
// 	return &Attribute{
// 		AttributeType: AttrUserName,
// 		Value:         []byte(userName),
// 	}
// }
