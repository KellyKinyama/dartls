typedef MessageMethod = int;

class MessageMethodDef {
  String name;
  MessageMethodDef(this.name);
}

// const (
const MessageMethodStunBinding = 0x0001;
const MessageMethodTurnAllocate = 0x0003;
const MessageMethodTurnRefresh = 0x0004;
const MessageMethodTurnSend = 0x0006;
const MessageMethodTurnData = 0x0007;
const MessageMethodTurnCreatePermission = 0x0008;
const MessageMethodTurnChannelBind = 0x0009;
const MessageMethodTurnConnect = 0x000a;
const MessageMethodTurnConnectionBind = 0x000b;
const MessageMethodTurnConnectionAttempt = 0x000c;
// )

Map<MessageMethod, MessageMethodDef> messageMethodMap = {
  MessageMethodStunBinding: MessageMethodDef("STUN Binding"),
  MessageMethodTurnAllocate: MessageMethodDef("TURN Allocate"),
  MessageMethodTurnRefresh: MessageMethodDef("TURN Refresh"),
  MessageMethodTurnSend: MessageMethodDef("TURN Send"),
  MessageMethodTurnData: MessageMethodDef("TURN Data"),
  MessageMethodTurnCreatePermission: MessageMethodDef("TURN CreatePermission"),
  MessageMethodTurnChannelBind: MessageMethodDef("TURN ChannelBind"),
  MessageMethodTurnConnect: MessageMethodDef("TURN Connect"),
  MessageMethodTurnConnectionBind: MessageMethodDef("TURN ConnectionBind"),
  MessageMethodTurnConnectionAttempt:
      MessageMethodDef("TURN ConnectionAttempt"),
};

// func (mm MessageMethod) String() string {
// 	messageMethodDef, ok := messageMethodMap[mm]
// 	if !ok {
// 		// Just return hex representation of unknown method.
// 		return fmt.Sprintf("0x%x", uint16(mm))
// 	}
// 	return messageMethodDef.Name
// }
