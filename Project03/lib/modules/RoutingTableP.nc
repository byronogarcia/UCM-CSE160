#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define TIMEOUT_MAX 10


module RoutingTableP{

	uses interface Timer<TMilli> as PeriodicTimer;
	uses interface SimpleSend as Sender;
	uses interface Receive as Receive;
	uses interface NeighborDiscovery;
	
	provides interface RoutingTable;	
}

implementation {

	//just use an array to do it
	routingTableS RoutingTableS[255];
	//keeps track of number of items in the array
	uint16_t counter; 


	pack myMsg;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
	

	command void RoutingTable.start(){		
		dbg(ROUTING_CHANNEL, "Starting Routing\n");
		call NeighborDiscovery.start();
		call PeriodicTimer.startPeriodic(10000);
	}
	
	command uint16_t RoutingTable.getNextHop(uint16_t finalDest){		
		uint32_t i = 0;	
			
		for (i = 0; i < 255; i++) {
			if (RoutingTableS[i].dest == finalDest && RoutingTableS[i].cost < 999) {
				return RoutingTableS[i].nextHop;
			}
		}
		
		return 999;
	}
	
	uint32_t findEntry(uint16_t dest) {
		uint32_t i;
		for (i = 0; i < counter; i++) {
			if (RoutingTableS[i].dest == dest) {
				return i;
			}
		}
		return 999;
	}
	

	void addToRoutingTable(uint16_t dest, uint16_t cost, uint16_t nextHop){
		
		if (counter >= 255 || dest == TOS_NODE_ID) {
	
		} else {
			RoutingTableS[counter].dest = dest;
			RoutingTableS[counter].cost = cost;	
			RoutingTableS[counter].nextHop = nextHop;	
			counter++;
		}
		return;
	}
	
	
	void getNeighbors(){
		uint16_t i = 0;
		uint16_t j = 0;
		void* tempNeighb;
		uint32_t tempTableSize = 0;
		
		
		struct neighborTableS TempNeighbors[255];
		tempNeighb = call NeighborDiscovery.getNeighborList();
		tempTableSize = call NeighborDiscovery.getNeighborListSize();
		memcpy(TempNeighbors, tempNeighb, sizeof(neighborTableS)*255);
		
		//add neighbor to the list with a cost of 1
		for (j = 0; j < tempTableSize; j++){
			if (findEntry(TempNeighbors[j].node)) {
				addToRoutingTable(TempNeighbors[j].node, 1, TempNeighbors[j].node);
			}
		}
		
		//set all neighbors to 999 to clear them 
		for (i = 0; i < counter; i++){
			if (RoutingTableS[i].cost == 1){
				RoutingTableS[i].cost = 999;
			}
		}	
		
		//goes through the routing table and only grabs neighbors who are in the refreshed neighbor list, old neighbors dies
		for (i = 0; i < counter; i++){
			for (j = 0; j < tempTableSize; j++){
				if (TempNeighbors[j].node == RoutingTableS[i].dest){
					RoutingTableS[i].nextHop = RoutingTableS[i].dest;
					RoutingTableS[i].cost = 1;		
				}
			}
				
		}
		
	}
	
	void sendRoutingTable(){
		uint16_t i = 0;
		uint16_t j = 0;
		routingTableS tempRoutingTable[1];
		
		
		//remove values

		for (i = 0; i < counter; i++){			
			if (RoutingTableS[i].cost == 999){
				RoutingTableS[i].nextHop = 999;
				RoutingTableS[i].cost = 999;
			}
		}

		//finds and sends neighbors only, Neighbors nexthop and dest are the same

		for (i = 0; i < counter; i++){
			if(RoutingTableS[i].dest == RoutingTableS[i].nextHop && RoutingTableS[i].nextHop != 999){
				tempRoutingTable[j].dest = RoutingTableS[i].dest;
				tempRoutingTable[j].nextHop = RoutingTableS[i].nextHop;
				tempRoutingTable[j].cost = RoutingTableS[i].cost;
				
		
				makePack(&myMsg, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, PROTOCOL_PING, (uint8_t*)tempRoutingTable, sizeof(routingTableS)*1);
				call Sender.send(myMsg, myMsg.dest);
			}	
		}
	}
	

	event void PeriodicTimer.fired(){
		
		getNeighbors();
		sendRoutingTable();
		
	}

	
	event message_t* Receive.receive(message_t* raw_msg, void* payload, uint8_t len){

		routingTableS tempRoutingTable[1];
		uint16_t i = 0;
		uint32_t j = 0;
		
		pack *msg = (pack *) payload;	
		memcpy(tempRoutingTable, msg->payload, sizeof(routingTableS)*1);
		j = findEntry(tempRoutingTable[i].dest);	

		//if I am neighbor, remove just in case, only draw neighbors from my own pool
		if (tempRoutingTable[i].nextHop == TOS_NODE_ID){
			tempRoutingTable[i].cost = 999;
		
		}

		//if it is in the list
		if (j != 999) {

			if (RoutingTableS[j].nextHop == msg->src) {
				//update the cost 
				if (tempRoutingTable[i].cost < 999){
					RoutingTableS[j].cost = tempRoutingTable[i].cost + 1;
				}
			//if my cost is lower update
			} else if ((tempRoutingTable[i].cost + 1) < RoutingTableS[j].cost) {
					RoutingTableS[j].cost = tempRoutingTable[i].cost + 1;
					RoutingTableS[j].nextHop = msg->src;
			}
				
		} else {
			addToRoutingTable(tempRoutingTable[i].dest, tempRoutingTable[i].cost, msg->src);

		}
		
		return raw_msg;
	}

	
	command void RoutingTable.print(){
		uint32_t i = 0;
		
		dbg(ROUTING_CHANNEL, "Printing Routing Table\n");
		dbg(ROUTING_CHANNEL, "Dest\tHop\tCount\n");
				
		for (i = 0; i < 255; i++) {
			if (RoutingTableS[i].dest != 0) {
				dbg( ROUTING_CHANNEL, "%u\t\t%u\t%u\n", RoutingTableS[i].dest, RoutingTableS[i].nextHop, RoutingTableS[i].cost);
			}
		}
	}

	
	
	
	
	 void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
	
	
	
	

}

