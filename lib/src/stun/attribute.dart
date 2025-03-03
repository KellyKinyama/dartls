import 'dart:typed_data';

import 'attribute_type.dart';

const attributeHeaderSize = 4;

class Attribute {
  AttributeType attributeType;
  Uint8List value; //           []byte
  int offsetInMessage;

  Attribute(this.attributeType, this.value, this.offsetInMessage);

  int getRawDataLength() {
    return value.length;
  }

  int getRawFullLength() {
    return attributeHeaderSize + value.length;
  }

  static Attribute decodeAttribute(Uint8List buf, int offset, int arrayLen) {
    if (arrayLen < attributeHeaderSize) {
      throw "errIncompleteTURNFrame";
    }
    ByteData reader = ByteData.sublistView(buf);
    final offsetBackup = offset;
    final attrType = reader.getUint16(offset);

    offset += 2;

    final attrLength = reader.getUint16(offset);

    offset += 2;

    return Attribute(
        attrType, buf.sublist(offset, offset + attrLength), offsetBackup);
  }

  Uint8List encode() {
    int attrLen = 4 + value.length;
    attrLen += (4 - (attrLen % 4)) % 4;
    Uint8List result = Uint8List(attrLen);
    ByteData writer = ByteData.sublistView(result);
    writer.setUint16(0, attributeType);
    writer.setUint16(2, value.length);
    // copy(result[4:], a.Value)
    result.setRange(4, 4 + value.length, value);
    return result;
  }

  
}





// func (a Attribute) String() string {
// 	return fmt.Sprintf("%s: [%s]", a.AttributeType, a.Value)
// }




