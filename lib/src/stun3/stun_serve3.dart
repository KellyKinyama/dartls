import 'dart:io';
import 'dart:typed_data';
import 'package:crc32_checksum/crc32_checksum.dart'; // For CRC32
import 'package:crypto/crypto.dart'; // For HMAC-SHA1
import 'dart:convert'; // For utf8 encoding

// --- STUN Attribute Type Constants ---
const int stunAttrXorMappedAddress = 0x0020;
const int stunAttrSoftware = 0x8022;
const int stunAttrMessageIntegrity = 0x0008;
const int stunAttrFingerprint = 0x8028;

// --- STUN Message Type Constants ---
const int stunBindingRequest = 0x0001;
const int stunBindingResponse = 0x0101;
const int stunBindingErrorResponse = 0x0111;

// --- STUN Magic Cookie ---
const int stunMagicCookie = 0x2112A442;

// --- Shared secret for MESSAGE-INTEGRITY (for demonstration purposes) ---
// In a real application, this would be dynamically retrieved based on user credentials or session.
final Uint8List sharedSecret =
    Uint8List.fromList(utf8.encode('my_stun_password'));

// --- Helper Functions ---

/// Calculates CRC32 checksum for the given bytes.
/// STUN Fingerprint uses polynomial 0xEDB88320 (reversed, standard is 0x04C11DB7)
/// This is typically what crc32_checksum package provides.
int calculateCrc32(Uint8List bytes) {
  return CRC32.checksum(bytes);
}

/// Calculates HMAC-SHA1 for the given bytes and key.
Uint8List calculateHmacSha1(Uint8List bytes, Uint8List key) {
  final hmac = Hmac(sha1, key);
  return Uint8List.fromList(hmac.convert(bytes).bytes);
}

// --- Main STUN Server Logic ---

Future<void> startStunServer(int port) async {
  final RawDatagramSocket socket =
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
  print('STUN server listening on UDP port ${socket.port}');

  await for (RawSocketEvent event in socket) {
    if (event == RawSocketEvent.read) {
      Datagram? datagram = socket.receive();
      if (datagram != null) {
        handleStunRequest(socket, datagram);
      }
    }
  }
}

void handleStunRequest(RawDatagramSocket socket, Datagram datagram) {
  final Uint8List requestBytes = datagram.data;
  final InternetAddress clientAddress = datagram.address;
  final int clientPort = datagram.port;

  if (requestBytes.length < 20) {
    print(
        'Received malformed packet from $clientAddress:$clientPort (too short)');
    return;
  }

  final ByteData requestData = ByteData.view(requestBytes.buffer);
  final int messageType = requestData.getUint16(0); // Bytes 0-1
  final int messageLength = requestData.getUint16(2); // Bytes 2-3
  final int magicCookie = requestData.getUint32(4); // Bytes 4-7
  final Uint8List transactionId = requestBytes.sublist(8, 20); // Bytes 8-19

  // Basic validation: Check Magic Cookie and message length
  if (magicCookie != stunMagicCookie) {
    print(
        'Received packet with invalid Magic Cookie from $clientAddress:$clientPort');
    // For a real server, you might send an error response or ignore
    return;
  }
  if (requestBytes.length != (20 + messageLength)) {
    print(
        'Received packet with invalid length from $clientAddress:$clientPort');
    return;
  }

  // Check if it's a Binding Request
  if (messageType != stunBindingRequest) {
    print(
        'Received non-Binding Request (type: ${messageType.toRadixString(16)}) from $clientAddress:$clientPort');
    // Optionally send an error response indicating unsupported message type
    return;
  }

  print('Received STUN Binding Request from $clientAddress:$clientPort');

  // --- Construct STUN Binding Response ---

  // 1. Build core attributes (XOR-MAPPED-ADDRESS, SOFTWARE)
  final BytesBuilder attributesBuilder = BytesBuilder();

  // XOR-MAPPED-ADDRESS Attribute
  final int xPort = clientPort ^ (stunMagicCookie >> 16);
  final Uint8List clientIpBytes = clientAddress.rawAddress;
  final ByteData clientIpData = ByteData.view(clientIpBytes.buffer);
  final int clientIpInt = clientIpData.getUint32(0); // Assuming IPv4
  final int xAddress = clientIpInt ^ stunMagicCookie;

  final BytesBuilder xorMappedAddressValueBuilder = BytesBuilder();
  xorMappedAddressValueBuilder.addByte(0); // Reserved
  xorMappedAddressValueBuilder.addByte(0); // Reserved
  xorMappedAddressValueBuilder.addByte(0); // Reserved
  xorMappedAddressValueBuilder.addByte(
      clientAddress.type == InternetAddressType.IPv4
          ? 0x01
          : 0x02); // Family (IPv4: 0x01, IPv6: 0x02)
  xorMappedAddressValueBuilder.addByte((xPort >> 8) & 0xFF);
  xorMappedAddressValueBuilder.addByte(xPort & 0xFF);
  xorMappedAddressValueBuilder.addByte((xAddress >> 24) & 0xFF);
  xorMappedAddressValueBuilder.addByte((xAddress >> 16) & 0xFF);
  xorMappedAddressValueBuilder.addByte((xAddress >> 8) & 0xFF);
  xorMappedAddressValueBuilder.addByte(xAddress & 0xFF);
  final Uint8List xorMappedAddressValue =
      xorMappedAddressValueBuilder.toBytes();

  attributesBuilder
      .addByte((stunAttrXorMappedAddress >> 8) & 0xFF); // Type high
  attributesBuilder.addByte(stunAttrXorMappedAddress & 0xFF); // Type low
  attributesBuilder
      .addByte((xorMappedAddressValue.length >> 8) & 0xFF); // Length high
  attributesBuilder.addByte(xorMappedAddressValue.length & 0xFF); // Length low
  attributesBuilder.add(xorMappedAddressValue);

  // SOFTWARE Attribute (optional)
  final String softwareName = 'Dart STUN Server v1.0';
  final Uint8List softwareBytes = Uint8List.fromList(utf8.encode(softwareName));
  final int softwarePadding = (4 - (softwareBytes.length % 4)) % 4;
  final Uint8List paddedSoftwareBytes =
      Uint8List(softwareBytes.length + softwarePadding);
  paddedSoftwareBytes.setAll(0, softwareBytes);

  attributesBuilder.addByte((stunAttrSoftware >> 8) & 0xFF);
  attributesBuilder.addByte(stunAttrSoftware & 0xFF);
  attributesBuilder.addByte((paddedSoftwareBytes.length >> 8) & 0xFF);
  attributesBuilder.addByte(paddedSoftwareBytes.length & 0xFF);
  attributesBuilder.add(paddedSoftwareBytes);

  // --- MESSAGE-INTEGRITY Attribute (Optional, if authentication is desired) ---
  // Must be calculated AFTER all other attributes (except FINGERPRINT)
  // and applied to the message *before* adding MESSAGE-INTEGRITY and FINGERPRINT.
  // The length in the STUN header needs to reflect the inclusion of MESSAGE-INTEGRITY.

  // Tentative message length (header + current attributes)
  int currentMessageLength = 20 + attributesBuilder.length;

  // Header bytes for HMAC calculation (without final message length)
  final BytesBuilder hmacHeaderBuilder = BytesBuilder();
  hmacHeaderBuilder.addByte((stunBindingResponse >> 8) & 0xFF);
  hmacHeaderBuilder.addByte(stunBindingResponse & 0xFF);
  hmacHeaderBuilder.addByte(
      (currentMessageLength >> 8) & 0xFF); // Placeholder length for HMAC
  hmacHeaderBuilder
      .addByte(currentMessageLength & 0xFF); // Placeholder length for HMAC
  hmacHeaderBuilder.addByte((stunMagicCookie >> 24) & 0xFF);
  hmacHeaderBuilder.addByte((stunMagicCookie >> 16) & 0xFF);
  hmacHeaderBuilder.addByte((stunMagicCookie >> 8) & 0xFF);
  hmacHeaderBuilder.addByte(stunMagicCookie & 0xFF);
  hmacHeaderBuilder.add(transactionId);

  // Bytes for HMAC calculation: header + current attributes
  final Uint8List bytesForHmac = Uint8List.fromList(
      hmacHeaderBuilder.toBytes() + attributesBuilder.toBytes());

  // Calculate HMAC-SHA1
  final Uint8List hmacHash = calculateHmacSha1(bytesForHmac, sharedSecret);

  // MESSAGE-INTEGRITY Attribute
  attributesBuilder.addByte((stunAttrMessageIntegrity >> 8) & 0xFF);
  attributesBuilder.addByte(stunAttrMessageIntegrity & 0xFF);
  attributesBuilder.addByte(0x00); // Length high (20 bytes for SHA1 hash)
  attributesBuilder.addByte(0x14); // Length low
  attributesBuilder.add(hmacHash);

  // Update total message length for FINGERPRINT calculation
  currentMessageLength = 20 + attributesBuilder.length;

  // --- FINGERPRINT Attribute (Optional) ---
  // Must be calculated AFTER all other attributes including MESSAGE-INTEGRITY
  // and applied to the message *before* adding FINGERPRINT itself.
  // The length in the STUN header needs to reflect the inclusion of FINGERPRINT.

  // Header bytes for CRC calculation (without final message length, but including MI if present)
  final BytesBuilder crcHeaderBuilder = BytesBuilder();
  crcHeaderBuilder.addByte((stunBindingResponse >> 8) & 0xFF);
  crcHeaderBuilder.addByte(stunBindingResponse & 0xFF);
  crcHeaderBuilder.addByte(
      (currentMessageLength >> 8) & 0xFF); // Placeholder length for CRC
  crcHeaderBuilder
      .addByte(currentMessageLength & 0xFF); // Placeholder length for CRC
  crcHeaderBuilder.addByte((stunMagicCookie >> 24) & 0xFF);
  crcHeaderBuilder.addByte((stunMagicCookie >> 16) & 0xFF);
  crcHeaderBuilder.addByte((stunMagicCookie >> 8) & 0xFF);
  crcHeaderBuilder.addByte(stunMagicCookie & 0xFF);
  crcHeaderBuilder.add(transactionId);

  // Bytes for CRC calculation: header + all current attributes (including MESSAGE-INTEGRITY)
  final Uint8List bytesForCrc = Uint8List.fromList(
      crcHeaderBuilder.toBytes() + attributesBuilder.toBytes());

  // Calculate CRC32
  final int crc32Checksum =
      calculateCrc32(bytesForCrc) ^ 0x5354554E; // XOR with XOR_MAGIC_COOKIE

  // FINGERPRINT Attribute
  attributesBuilder.addByte((stunAttrFingerprint >> 8) & 0xFF);
  attributesBuilder.addByte(stunAttrFingerprint & 0xFF);
  attributesBuilder.addByte(0x00); // Length high (4 bytes for CRC32)
  attributesBuilder.addByte(0x04); // Length low
  attributesBuilder.addByte((crc32Checksum >> 24) & 0xFF);
  attributesBuilder.addByte((crc32Checksum >> 16) & 0xFF);
  attributesBuilder.addByte((crc32Checksum >> 8) & 0xFF);
  attributesBuilder.addByte(crc32Checksum & 0xFF);

  // Final message length
  final Uint8List finalAttributesBytes = attributesBuilder.toBytes();
  final int finalMessageLength = finalAttributesBytes.length;

  // --- STUN Message Header ---
  final BytesBuilder headerBuilder = BytesBuilder();
  headerBuilder
      .addByte((stunBindingResponse >> 8) & 0xFF); // Message Type high byte
  headerBuilder.addByte(stunBindingResponse & 0xFF); // Message Type low byte
  headerBuilder
      .addByte((finalMessageLength >> 8) & 0xFF); // Message Length high byte
  headerBuilder.addByte(finalMessageLength & 0xFF); // Message Length low byte
  headerBuilder.addByte((stunMagicCookie >> 24) & 0xFF);
  headerBuilder.addByte((stunMagicCookie >> 16) & 0xFF);
  headerBuilder.addByte((stunMagicCookie >> 8) & 0xFF);
  headerBuilder.addByte(stunMagicCookie & 0xFF);
  headerBuilder.add(transactionId);

  final Uint8List responseBytes =
      Uint8List.fromList(headerBuilder.toBytes() + finalAttributesBytes);

  // Send the response
  socket.send(responseBytes, clientAddress, clientPort);
  print(
      'Sent STUN Binding Response with MI and FP to $clientAddress:$clientPort');
}

// --- Main function to run the server ---
void main() {
  startStunServer(3478); // Default STUN port
}
