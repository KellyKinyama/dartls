import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

class IPFamily {
  static const IPv4 = 0x01;
  static const IPv6 = 0x02;
}

class MappedAddress {
  final int ipFamily;
  final String ip;
  final int port;

  MappedAddress({required this.ipFamily, required this.ip, required this.port});
}

class Attribute {
  final String attributeType;
  final List<int> value;

  Attribute({required this.attributeType, required this.value});
}

const int magicCookie = 0x2112A442;
const String AttrXorMappedAddress = 'XorMappedAddress';
const String AttrUserName = 'UserName';

class StunClient {
  // Create the XOR Mapped Address Attribute
  static Attribute createAttrXorMappedAddress(
      List<int> transactionID, RawAddress addr) {
    final xorMask = List<int>.filled(16, 0);

    // First 4 bytes of the xorMask are the magic cookie
    xorMask.setRange(0, 4, _toBytes(magicCookie));

    // Copy the transactionID into the xorMask starting from byte 4
    xorMask.setRange(4, 16, transactionID);

    // Prepare the addressBytes from the address IP (IPv4)
    final addressBytes = addr.address.rawAddress.sublist(0, 4);

    // Modify the port based on xorMask
    final portModifier = ((xorMask[0] << 8) & 0x0000FF00) |
        (xorMask[1] & 0x000000FF);
    final port = addr.port ^ portModifier;

    // XOR the addressBytes with xorMask
    final xorIP = List<int>.from(addressBytes);
    for (int i = 0; i < xorIP.length; i++) {
      xorIP[i] ^= xorMask[i + 4];
    }

    // Build the final value for the attribute
    final value = List<int>.filled(8, 0);
    value[1] = IPFamily.IPv4;
    value.setRange(2, 4, _toBytes(port));
    value.setRange(4, 8, xorIP);

    return Attribute(attributeType: AttrXorMappedAddress, value: value);
  }

  // Decode the XOR Mapped Address Attribute
  static MappedAddress decodeAttrXorMappedAddress(
      Attribute attr, List<int> transactionID) {
    final xorMask = List<int>.filled(16, 0);

    // First 4 bytes of the xorMask are the magic cookie
    xorMask.setRange(0, 4, _toBytes(magicCookie));

    // Copy the transactionID into the xorMask starting from byte 4
    xorMask.setRange(4, 16, transactionID);

    // XOR the address bytes from the attribute value
    final xorIP = List<int>.filled(16, 0);
    for (int i = 0; i < attr.value.length - 4; i++) {
      xorIP[i] = attr.value[i + 4] ^ xorMask[i];
    }

    final family = attr.value[1];
    var ip = '';
    if (family == IPFamily.IPv4) {
      ip = xorIP.sublist(0, 4).join('.');
    }

    final port = _fromBytes(xorMask.sublist(0, 2)) ^ _fromBytes(xorIP.sublist(0, 2));

    return MappedAddress(ipFamily: family, ip: ip, port: port);
  }

  // Create the User Name Attribute
  static Attribute createAttrUserName(String userName) {
    return Attribute(attributeType: AttrUserName, value: utf8.encode(userName));
  }

  // Helper method to convert an integer to a byte array
  static List<int> _toBytes(int value) {
    final byteData = ByteData(4);
    byteData.setUint32(0, value, Endian.big);
    return byteData.buffer.asUint8List();
  }

  // Helper method to convert a byte array to an integer
  static int _fromBytes(List<int> bytes) {
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    return byteData.getUint16(0, Endian.big);
  }
}

void main() {
  // Example usage
  final transactionID = List<int>.generate(12, (i) => i); // Example transaction ID
  final addr = RawAddress(InternetAddress('192.168.0.1'), 3478);

  final attr = StunClient.createAttrXorMappedAddress(transactionID, addr);
  print('Created Attribute: ${attr.attributeType}, Value: ${attr.value}');

  final mappedAddr = StunClient.decodeAttrXorMappedAddress(attr, transactionID);
  print('Decoded Mapped Address: ${mappedAddr.ip}:${mappedAddr.port}');
}
