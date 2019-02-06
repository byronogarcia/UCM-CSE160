#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPPacket.h"
#include <Timer.h>

module TransportP{
	
	uses interface Timer<TMilli> as beaconTimer;

	uses interface SimpleSend as Sender;
	uses interface Forwarder;


	uses interface List<socket_t> as SocketList;
	uses interface Queue<pack> as packetQueue;

	uses interface RoutingTable;

	provides interface Transport;
}
implementation{

	socket_t getSocket(uint8_t destPort, uint8_t srcPort);
	socket_t getServerSocket(uint8_t destPort);


	event void beaconTimer.fired(){
		pack myMsg = call packetQueue.head();
		pack sendMsg;

		//cast as a tcp_pack
		tcp_pack* myTCPPack = (tcp_pack *)(myMsg.payload);
		socket_t mySocket = getSocket(myTCPPack->srcPort, myTCPPack->destPort);
		
		if(mySocket.dest.port){
			call SocketList.pushback(mySocket);

			//have to cast it as a uint8_t* pointer

			call Transport.makePack(&sendMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
			call Sender.send(sendMsg, mySocket.dest.addr);
		}
	

	}

	socket_t getSocket(uint8_t destPort, uint8_t srcPort){
		socket_t mySocket;
		uint32_t i = 0;
		uint32_t size = call SocketList.size();
		
		for (i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if(mySocket.dest.port == srcPort && mySocket.src.port == destPort){
				return mySocket;
			}
		}

	}

	socket_t getServerSocket(uint8_t destPort){
		socket_t mySocket;
		bool foundSocket;
		uint16_t i = 0;
		uint16_t size = call SocketList.size();
		
		for(i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if(mySocket.src.port == destPort && mySocket.state == LISTEN){
				return mySocket;
			}
		}
		dbg(TRANSPORT_CHANNEL, "Socket not found. \n");
	}

	command error_t Transport.connect(socket_t fd){
		pack myMsg;
		tcp_pack* myTCPPack;
		socket_t mySocket = fd;
		
		myTCPPack = (tcp_pack*)(myMsg.payload);
		myTCPPack->destPort = mySocket.dest.port;
		myTCPPack->srcPort = mySocket.src.port;
		myTCPPack->ACK = 0;
		myTCPPack->seq = 1;
		myTCPPack->flags = SYN_FLAG;

		call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
		mySocket.state = SYN_SENT;

		dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);

		dbg(ROUTING_CHANNEL, "CLIENT TRYING \n");

		call Sender.send(myMsg, mySocket.dest.addr);

}	
	
	void connectDone(socket_t fd){
		pack myMsg;
		tcp_pack* myTCPPack;
		socket_t mySocket = fd;
		uint16_t i = 0;

	
		myTCPPack = (tcp_pack*)(myMsg.payload);
		myTCPPack->destPort = mySocket.dest.port;
		myTCPPack->srcPort = mySocket.src.port;
		myTCPPack->flags = DATA_FLAG;
		myTCPPack->seq = 0;

		i = 0;
		while(i < TCP_PACKET_MAX_PAYLOAD_SIZE && i <= mySocket.effectiveWindow){
			myTCPPack->payload[i] = i;
			i++;
		}

		myTCPPack->ACK = i;
		call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);

		dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);

		dbg(ROUTING_CHANNEL, "SERVER CONNECTED\n");

		call packetQueue.enqueue(myMsg);

		call beaconTimer.startOneShot(140000);

		call Sender.send(myMsg, mySocket.dest.addr);

}	

	command error_t Transport.receive(pack* msg){
		uint8_t srcPort = 0;
		uint8_t destPort = 0;
		uint8_t seq = 0;
		uint8_t lastAck = 0;
		uint8_t flags = 0;
		uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE;
		uint16_t i = 0;
		uint16_t j = 0;
		uint32_t key = 0;
		socket_t mySocket;
		tcp_pack* myMsg = (tcp_pack *)(msg->payload);


		pack myNewMsg;
		tcp_pack* myTCPPack;

		srcPort = myMsg->srcPort;
		destPort = myMsg->destPort;
		seq = myMsg->seq;
		lastAck = myMsg->ACK;
		flags = myMsg->flags;

		if(flags == SYN_FLAG || flags == SYN_ACK_FLAG || flags == ACK_FLAG){

			if(flags == SYN_FLAG){
				dbg(TRANSPORT_CHANNEL, "Got SYN! \n");
				mySocket = getServerSocket(destPort);
				if(mySocket.state == LISTEN){
					mySocket.state = SYN_RCVD;
					mySocket.dest.port = srcPort;
					mySocket.dest.addr = msg->src;
					call SocketList.pushback(mySocket);
				
					myTCPPack = (tcp_pack *)(myNewMsg.payload);
					myTCPPack->destPort = mySocket.dest.port;
					myTCPPack->srcPort = mySocket.src.port;
					myTCPPack->seq = 1;
					myTCPPack->ACK = seq + 1;
					myTCPPack->flags = SYN_ACK_FLAG;
					dbg(TRANSPORT_CHANNEL, "Sending SYN ACK! \n");
					call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
					call Sender.send(myNewMsg, mySocket.dest.addr);
				}
			}

			else if(flags == SYN_ACK_FLAG){
				dbg(TRANSPORT_CHANNEL, "Got SYN ACK! \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = ESTABLISHED;
				call SocketList.pushback(mySocket);

				myTCPPack = (tcp_pack*)(myNewMsg.payload);
				myTCPPack->destPort = mySocket.dest.port;
				myTCPPack->srcPort = mySocket.src.port;
				myTCPPack->seq = 1;
				myTCPPack->ACK = seq + 1;
				myTCPPack->flags = ACK_FLAG;
				dbg(TRANSPORT_CHANNEL, "SENDING ACK \n");
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
				call Sender.send(myNewMsg, mySocket.dest.addr);

				connectDone(mySocket);
			}

			else if(flags == ACK_FLAG){
				dbg(TRANSPORT_CHANNEL, "GOT ACK \n");
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == SYN_RCVD){
					mySocket.state = ESTABLISHED;
					call SocketList.pushback(mySocket);
				}
			}
		}

		if(flags == DATA_FLAG || flags == DATA_ACK_FLAG){

			if(flags == DATA_FLAG){
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == ESTABLISHED){
					myTCPPack = (tcp_pack*)(myNewMsg.payload);
					if(myMsg->payload[0] != 0){
						i = mySocket.lastRcvd + 1;
						j = 0;
						while(j < myMsg->ACK){
							mySocket.rcvdBuff[i] = myMsg->payload[j];
							mySocket.lastRcvd = myMsg->payload[j];
							i++;
							j++;
						}
					}else{
						i = 0;
						while(i < myMsg->ACK){
							mySocket.rcvdBuff[i] = myMsg->payload[i];
							mySocket.lastRcvd = myMsg->payload[i];
							i++;
						}
					}

				mySocket.effectiveWindow = SOCKET_BUFFER_SIZE - mySocket.lastRcvd + 1;
				call SocketList.pushback(mySocket);
			
				myTCPPack->destPort = mySocket.dest.port;
				myTCPPack->srcPort = mySocket.src.port;
				myTCPPack->seq = seq;
				myTCPPack->ACK = seq + 1;
				myTCPPack->lastACK = mySocket.lastRcvd;
				myTCPPack->window = mySocket.effectiveWindow;
				myTCPPack->flags = DATA_ACK_FLAG;
				dbg(TRANSPORT_CHANNEL, "SENDING DATA ACK FLAG\n");
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0 , myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
				call Sender.send(myNewMsg, mySocket.dest.addr);
				}
			
			} else if (flags == DATA_ACK_FLAG){
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == ESTABLISHED){
					if(myMsg->window != 0 && myMsg->lastACK != mySocket.effectiveWindow){
						myTCPPack = (tcp_pack*)(myNewMsg.payload);
						i = myMsg->lastACK + 1;
						j = 0;
						
						while(j < myMsg->window && j < TCP_PACKET_MAX_PAYLOAD_SIZE && i <= mySocket.effectiveWindow){
							myTCPPack->payload[j] = i;
							i++;
							j++;
						}
					
						call SocketList.pushback(mySocket);
						myTCPPack->flags = DATA_FLAG;
						myTCPPack->destPort = mySocket.dest.port;
						myTCPPack->srcPort = mySocket.src.port;
						myTCPPack->ACK = i - 1 - myMsg->lastACK;
						myTCPPack->seq = lastAck;
						call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
	
						//call Sender. send(myMsg, mySocket.dest.addr);
						
	
						call packetQueue.dequeue();
						call packetQueue.enqueue(myNewMsg);
						dbg(TRANSPORT_CHANNEL, "SENDING NEW DATA \n");
						call Sender.send(myNewMsg, mySocket.dest.addr);
					}else{

						mySocket.state = FIN_FLAG;
						call SocketList.pushback(mySocket);
						myTCPPack = (tcp_pack*)(myNewMsg.payload);
						myTCPPack->destPort = mySocket.dest.port;
						myTCPPack->srcPort = mySocket.src.port;
						myTCPPack->seq = 1;
						myTCPPack->ACK = seq + 1;
						myTCPPack->flags = FIN_FLAG;
						call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
						call Sender.send(myNewMsg, mySocket.dest.addr);

					}
				}
			}
		}
		if(flags == FIN_FLAG || flags == FIN_ACK){
			if(flags == FIN_FLAG){
				dbg(TRANSPORT_CHANNEL, "GOT FIN FLAG \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = CLOSED;
				mySocket.dest.port = srcPort;
				mySocket.dest.addr = msg->src;
		
				myTCPPack = (tcp_pack *)(myNewMsg.payload);
				myTCPPack->destPort = mySocket.dest.port;
				myTCPPack->srcPort = mySocket.src.port;
				myTCPPack->seq = 1;
				myTCPPack->ACK = seq + 1;
				myTCPPack->flags = FIN_ACK;
				
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
				call Sender.send(myNewMsg, mySocket.dest.addr);
			}
			if(flags == FIN_ACK){
				dbg(TRANSPORT_CHANNEL, "GOT FIN ACK \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = CLOSED;
			}
		}
}

	command void Transport.setTestServer(){

		socket_t mySocket;
		socket_addr_t myAddr;
		
		myAddr.addr = TOS_NODE_ID;
		myAddr.port = 123;
		
		mySocket.src = myAddr;
		mySocket.state = LISTEN;
	
		call SocketList.pushback(mySocket);
	}
	command void Transport.setTestClient(){

		socket_t mySocket;
		socket_addr_t myAddr;

		myAddr.addr = TOS_NODE_ID;
		myAddr.port = 200;

		mySocket.dest.port = 123;
		mySocket.dest.addr = 1;
	
		mySocket.src = myAddr;
		
		call SocketList.pushback(mySocket);
		call Transport.connect(mySocket);
	}
	command void Transport.makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
}
}
