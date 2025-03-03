typedef MessageClass = int;

class MessageClassDef {
  String name;
  MessageClassDef(this.name);

  @override
  String toString() {
    // TODO: implement toString
    return "MessageClassDef {$name}";
  }
}

// const (
const MessageClassRequest = 0x00;
const MessageClassIndication = 0x01;
const MessageClassSuccessResponse = 0x02;
const MessageClassErrorResponse = 0x03;
// )

Map<MessageClass, MessageClassDef> messageClassMap = {
  MessageClassRequest: MessageClassDef("request"),
  MessageClassIndication: MessageClassDef("indication"),
  MessageClassSuccessResponse: MessageClassDef("success response"),
  MessageClassErrorResponse: MessageClassDef("error response"),
};
