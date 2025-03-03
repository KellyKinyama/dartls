

import 'attributes.dart';

class StunClient {
	String serverAddr ;
	String ufrag      ;
	String pwd        ;

  StunClient(this.serverAddr,this.ufrag,this.pwd);

  // https://github.com/ccding/go-stun
MappedAddress discover() {
	final transactionID= generateTransactionID();
	// if err != nil {
	// 	return nil, err
	// }
	final serverUDPAddr = net.ResolveUDPAddr("udp", serverAddr);
	// if err != nil {
	// 	return nil, err
	// 	//return NATError, nil, err
	// }
	final bindingRequest = createBindingRequest(transactionID);
	final encodedBindingRequest = bindingRequest.encode(pwd);
	conn, err := net.ListenUDP("udp", nil)
	// if err != nil {
	// 	return nil, err
	// }
	defer conn.Close()
	conn.WriteToUDP(encodedBindingRequest, serverUDPAddr)
	buf := make([]byte, 1024)

	for {
		bufLen, addr, err := conn.ReadFromUDP(buf)
		if err != nil {
			return nil, err
		}
		// If requested target server address and responder address not fit, ignore the packet
		if !addr.IP.Equal(serverUDPAddr.IP) || addr.Port != serverUDPAddr.Port {
			continue
		}
		stunMessage, stunErr := DecodeMessage(buf, 0, bufLen)
		if stunErr != nil {
			panic(stunErr)
		}
		stunMessage.Validate(c.Ufrag, c.Pwd)
		if !bytes.Equal(stunMessage.TransactionID[:], transactionID[:]) {
			continue
		}
		xorMappedAddressAttr, ok := stunMessage.Attributes[AttrXorMappedAddress]
		if !ok {
			continue
		}
		mappedAddress := DecodeAttrXorMappedAddress(xorMappedAddressAttr, stunMessage.TransactionID)
		return mappedAddress, nil
	}
}
}

StunClient newStunClient(String serverAddr, String ufrag, String pwd) {
	return StunClient(
		 serverAddr,
		 ufrag,
		 pwd,
  );
}



func generateTransactionID() ([12]byte, error) {
	result := [12]byte{}
	_, err := rand.Read(result[:])
	if err != nil {
		return result, err
	}
	return result, nil
}

func createBindingRequest(transactionID [12]byte) *Message {
	responseMessage := NewMessage(MessageTypeBindingRequest, transactionID)
	return responseMessage
}
