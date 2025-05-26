import 'dart:io';
import 'dart:typed_data';

Future<void> startStunServer(int port) async {
  // Bind to the UDP port
  final RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
  print('STUN server listening on UDP port ${socket.port}');

  // Listen for incoming datagrams
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

  // Basic check for STUN message (e.g., minimum length)
  if (requestBytes.length < 20) { // STUN header is 20 bytes
    print('Received malformed packet from $clientAddress:$clientPort');
    return;
  }

  // --- STUN Message Parsing (Simplified) ---
  // You would need to implement robust parsing here.
  // For demonstration, let's assume it's a valid Binding Request.

  // Extract Magic Cookie and Transaction ID from the request
  final ByteData requestData = ByteData.view(requestBytes.buffer);
  final int magicCookie = requestData.getUint32(4); // Bytes 4-7
  final Uint8List transactionId = requestBytes.sublist(8, 20); // Bytes 8-19

  // Check if it's a Binding Request (Message Type 0x0001)
  final int messageType = requestData.getUint16(0); // Bytes 0-1
  if (messageType != 0x0001) {
    print('Received non-Binding Request (type: $messageType) from $clientAddress:$clientPort');
    // Optionally send an error response
    return;
  }

  print('Received STUN Binding Request from $clientAddress:$clientPort');

  // --- Construct STUN Binding Response ---
  // Message Type: Binding Response (0x0101)
  // Magic Cookie: Same as request
  // Transaction ID: Same as request

  // Attributes to include: XOR-MAPPED-ADDRESS
  // XOR-MAPPED-ADDRESS format:
  // 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
  // +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  // |         Reserved (must be 0)        | Family |
  // +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  // |              X-Port (16 bits)                 |
  // +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
  // |               X-Address (32 bits)             |
  // +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

  // Calculate X-Port and X-Address
  final int xPort = clientPort ^ (magicCookie >> 16); // XOR with top 16 bits of Magic Cookie
  final Uint8List clientIpBytes = clientAddress.rawAddress;
  final ByteData clientIpData = ByteData.view(clientIpBytes.buffer);
  final int clientIpInt = clientIpData.getUint32(0); // Assuming IPv4
  final int xAddress = clientIpInt ^ magicCookie;

  // Build the XOR-MAPPED-ADDRESS attribute
  final BytesBuilder xorMappedAddressBuilder = BytesBuilder();
  xorMappedAddressBuilder.addByte(0); // Reserved
  xorMappedAddressBuilder.addByte(0); // Reserved
  xorMappedAddressBuilder.addByte(0); // Reserved
  xorMappedAddressBuilder.addByte(clientAddress.type == InternetAddressType.IPv4 ? 0x01 : 0x02); // Family (IPv4: 0x01, IPv6: 0x02)
  xorMappedAddressBuilder.addByte((xPort >> 8) & 0xFF); // X-Port high byte
  xorMappedAddressBuilder.addByte(xPort & 0xFF);       // X-Port low byte
  xorMappedAddressBuilder.addByte((xAddress >> 24) & 0xFF); // X-Address byte 3
  xorMappedAddressBuilder.addByte((xAddress >> 16) & 0xFF); // X-Address byte 2
  xorMappedAddressBuilder.addByte((xAddress >> 8) & 0xFF);  // X-Address byte 1
  xorMappedAddressBuilder.addByte(xAddress & 0xFF);         // X-Address byte 0
  final Uint8List xorMappedAddressValue = xorMappedAddressBuilder.toBytes();

  // STUN Attribute Header: Type (2 bytes), Length (2 bytes)
  final BytesBuilder responseBuilder = BytesBuilder();
  // XOR-MAPPED-ADDRESS Type (0x0020)
  responseBuilder.addByte(0x00);
  responseBuilder.addByte(0x20);
  // Length of XOR-MAPPED-ADDRESS value (8 bytes for IPv4)
  responseBuilder.addByte(0x00);
  responseBuilder.addByte(0x08);
  responseBuilder.add(xorMappedAddressValue);

  // --- Add SOFTWARE attribute (optional) ---
  final String softwareName = 'Dart STUN Server';
  final Uint8List softwareBytes = Uint8List.fromList(softwareName.codeUnits);
  // Pad to a multiple of 4 bytes
  final int softwarePadding = (4 - (softwareBytes.length % 4)) % 4;
  final Uint8List paddedSoftwareBytes = Uint8List(softwareBytes.length + softwarePadding);
  paddedSoftwareBytes.setAll(0, softwareBytes);

  // SOFTWARE Type (0x8022)
  responseBuilder.addByte(0x80);
  responseBuilder.addByte(0x22);
  // Length of SOFTWARE value
  responseBuilder.addByte((paddedSoftwareBytes.length >> 8) & 0xFF);
  responseBuilder.addByte(paddedSoftwareBytes.length & 0xFF);
  responseBuilder.add(paddedSoftwareBytes);

  // --- STUN Message Header ---
  // Message Type: Binding Response (0x0101)
  // Message Length: Length of all attributes
  // Magic Cookie: 0x2112A442
  // Transaction ID: From request

  final Uint8List attributesBytes = responseBuilder.toBytes();
  final int messageLength = attributesBytes.length;

  final BytesBuilder headerBuilder = BytesBuilder();
  headerBuilder.addByte(0x01); // Message Type high byte (Binding Response)
  headerBuilder.addByte(0x01); // Message Type low byte
  headerBuilder.addByte((messageLength >> 8) & 0xFF); // Message Length high byte
  headerBuilder.addByte(messageLength & 0xFF);       // Message Length low byte
  headerBuilder.addByte(0x21); // Magic Cookie byte 0
  headerBuilder.addByte(0x12); // Magic Cookie byte 1
  headerBuilder.addByte(0xA4); // Magic Cookie byte 2
  headerBuilder.addByte(0x42); // Magic Cookie byte 3
  headerBuilder.add(transactionId); // Transaction ID

  final Uint8List responseBytes = headerBuilder.toBytes() + attributesBytes;

  // Send the response
  socket.send(responseBytes, clientAddress, clientPort);
  print('Sent STUN Binding Response to $clientAddress:$clientPort');
}

// --- Main function to run the server ---
void main() {
  // You can specify the port here, or use the default STUN port 3478
  startStunServer(3478);
}