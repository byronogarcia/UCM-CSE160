// Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../interfaces/listInfo.h"
#define BEACON_PERIOD 9000
#define NEIGHBORLIST_SIZE 255

module NeighborDiscoveryP{
	// uses interface
	uses interface Timer<TMilli> as beaconTimer;
	uses interface SimpleSend as NeighborSender;
	uses interface Receive as MainReceive;
	
	provides interface NeighborDiscovery;
}

implementation{

	pack sendPackage;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

	uint16_t counter = 0;
	struct neighborTableS Neighbors[NEIGHBORLIST_SIZE];
		
	void updateNeighborList(uint16_t newSrc){
		uint32_t i = 0;

		for (i = 0; i < NEIGHBORLIST_SIZE; i++){
			if (Neighbors[i].node == newSrc){
				Neighbors[i].age = 5;
				return;
			}
		}
		
		Neighbors[counter].node = newSrc;
		Neighbors[counter].age = 5;
		counter++;
	
		return;
	}

	void refreshNeighborList(){
		uint32_t i = 0;
		uint32_t j = 0;
	
		for(i = 0; i < NEIGHBORLIST_SIZE; i++){
			if(Neighbors[i].age > 1){
				Neighbors[i].age--;
			}
		}
	
		for(i = 0; i < NEIGHBORLIST_SIZE; i++){
			if(Neighbors[i].age == 1){
				for(j = i; j < NEIGHBORLIST_SIZE - 1; j++){
					Neighbors[j].node = Neighbors[j + 1].node;
					Neighbors[j].age = Neighbors[j + 1].age;
				}

			Neighbors[NEIGHBORLIST_SIZE - 1].node = 0;
			Neighbors[NEIGHBORLIST_SIZE - 1].age = 0;
			counter--;
			}
		}
	}

	command neighborTableS* NeighborDiscovery.getNeighborList(){
		return Neighbors;
	}

	command uint16_t NeighborDiscovery.getNeighborListSize(){
		return counter;
	}

	command void NeighborDiscovery.start(){
		dbg(NEIGHBOR_CHANNEL, "Starting Neighbor Discovery \n");
		call beaconTimer.startPeriodic(BEACON_PERIOD);
	}

	command void NeighborDiscovery.print(){
		uint32_t i = 0;
		dbg(NEIGHBOR_CHANNEL, "Printing Neighbors of %u:\n", TOS_NODE_ID);
		for(i = 0; i < NEIGHBORLIST_SIZE; i++){
			if(Neighbors[i].node != 0){
				dbg(NEIGHBOR_CHANNEL, "Neighbor %u, TTL %u \n", Neighbors[i].node, Neighbors[i].age);
			}
		}
	}

	event void beaconTimer.fired(){

		//dbg(NEIGHBOR_CHANNEL, "Sending Neighbor Packet\n");

		//needs "test" in the payload or it dosent work!!!!
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, PROTOCOL_PING, "test", PACKET_MAX_PAYLOAD_SIZE);

		call NeighborSender.send(sendPackage, AM_BROADCAST_ADDR);
		refreshNeighborList();
	}

	event message_t* MainReceive.receive(message_t* myMsg, void* payload, uint8_t len){
		pack *msg = (pack *) payload;
		//dbg(NEIGHBOR_CHANNEL, "NeighborDiscovery got Packet\n");
		if(msg->dest == AM_BROADCAST_ADDR){
			msg->dest = msg->src;
			msg->src = TOS_NODE_ID;
			msg->protocol = PROTOCOL_PINGREPLY;
			call NeighborSender.send(*msg, msg->dest);
		}else if(msg->dest == TOS_NODE_ID){
			updateNeighborList(msg->src);
		}
		return myMsg;
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
