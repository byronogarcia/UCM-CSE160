/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"

#define APP_BUFFER_SIZE 40

module Node{
   uses interface Boot;

	uses interface Timer<TMilli> as beaconTimer;
	uses interface SplitControl as AMControl;
	uses interface Receive;

	uses interface SimpleSend as Sender;
	
	uses interface SimpleSend as FloodSender;
	uses interface Receive as FloodReceive;

	uses interface NeighborDiscovery;
	uses interface RoutingTable;

	uses interface CommandHandler;

	uses interface SimpleSend as ForwardSender;
	uses interface Receive as ForwardReceive;

}

implementation{
   pack sendPackage;
	uint16_t nodeSeq = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

	socket_t getSocket(uint8_t destPort, uint8_t srcPort);
	socket_t getServerSocket(uint8_t destPort);
	void connect(socket_t mySocket);
	void connectDone(socket_t mySocket);
	void TCPReceive(pack *myMsg);


   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");

   }

   event void AMControl.startDone(error_t err){
	//call NeighborDiscovery.start();
	call RoutingTable.start();
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

	event message_t* FloodReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}

	event message_t* ForwardReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}

	event void beaconTimer.fired(){


}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
		
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
	nodeSeq++;
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, nodeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){
	dbg(GENERAL_CHANNEL, "PRINT NEIGHBOR LIST EVENT \n");
	call NeighborDiscovery.print();
   }

   event void CommandHandler.printRouteTable(){
	dbg(GENERAL_CHANNEL, "PRINT ROUTING TABLE EVENT \n");
	call RoutingTable.print();
	}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){

}

   event void CommandHandler.setTestClient(){

}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}


   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

}
