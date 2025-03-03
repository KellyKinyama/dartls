import 'dart:typed_data';

// CRC32 polynomial (reverse)
const int _crc32Polynomial = 0xedb88320;
const int fingerprintXorMask = 0x5354554e;

// Function to calculate the CRC32 checksum
int calculateCRC32(Uint8List data) {
  // Initialize the CRC32 checksum value to all ones
  int crc = 0xffffffff;

  // Iterate through each byte in the data
  for (int i = 0; i < data.length; i++) {
    crc ^= data[i];
    
    // Perform the CRC32 bitwise operation for each bit in the byte
    for (int j = 0; j < 8; j++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ _crc32Polynomial;
      } else {
        crc >>= 1;
      }
    }
  }

  // Return the final CRC32 value, applying the XOR mask
  return crc ^ fingerprintXorMask;
}

void main() {
  // Example usage
  Uint8List data = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
  int checksum = calculateCRC32(data);
  print('CRC32 checksum: ${checksum.toRadixString(16)}');
}
