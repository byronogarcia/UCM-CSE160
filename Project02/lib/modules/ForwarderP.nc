#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"


module ForwarderP{
	provides interface SimpleSend as ForwardSender;
	provides interface Receive as MainReceive;

	uses interface SimpleSend as Sender;
	uses interface Receive as InternalReceiver;

	uses interface RoutingTable;
}

implementation{

	command error_t ForwardSender.send(pack msg, uint16_t dest){
		uint16_t nextHop = 0;
		nextHop = call RoutingTable.getNextHop(dest);

		if(nextHop == 999 || nextHop < 1){
			dbg(ROUTING_CHANNEL, "No Route Found\n");
		}else{
			dbg(ROUTING_CHANNEL, "Forwarding Packet to %u to get to %u\n", nextHop, dest);
			call Sender.send(msg, nextHop);
		}
	}

	//event message_t* RoutingTableReceive.receive(message_t* msg, void* payload, uint8_t len){
		//return msg;
	//}

	event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
		pack *myMsg = (pack *) payload;
		//myMsg->TTL -= 1;
		uint16_t holder = 0;
		uint16_t nextHop = 0;

		myMsg->TTL -= 1;

		if(myMsg->dest == TOS_NODE_ID){
			if(myMsg->protocol == PROTOCOL_PINGREPLY){
				dbg(ROUTING_CHANNEL, "Got PingReply\n");
			} else if (myMsg->protocol == PROTOCOL_PING){
				holder = myMsg->src;
				myMsg->src = myMsg->dest;
				myMsg->dest = holder;
				myMsg->TTL = 15;
				call ForwardSender.send(*myMsg, myMsg->dest);
		}else{
			if(myMsg->TTL == 0){
				dbg(ROUTING_CHANNEL, "Dropping Packet");
			}
				
			nextHop = call RoutingTable.getNextHop(myMsg->dest);
			if(nextHop < 1 || nextHop >= 999){
				dbg(ROUTING_CHANNEL, "Dropping Packet");
					return msg;
			}
			call ForwardSender.send(*myMsg, nextHop);
		}
		return msg;
	}


		

}
}
		
