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

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface Random as Random;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   // List for now, hashmaps WIP
   uses interface List<Neighbor> as NeighborList;
   uses interface Timer<TMilli> as perTimer;

   uses interface List<pack> as PacketList;
}

implementation{

   pack sendPackage;

   uint16_t seqNum = 0;           

// Protos here
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");             
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         call perTimer.startPeriodic(1000);                     
      }else{
         call AMControl.start();                                            
      }
   }
   
  void sendWithTimerPing(pack *Package);

  void sendWithTimerDiscovery(pack Package, uint16_t destination);


   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      uint16_t messageHash = generateUniqueMessageHash(recievedPackage -> payload, recievedPackage -> dest, recievedPackage -> seq);

    dbg(GENERAL_CHANNEL, "Got the packet: %i\n")

    /* WIP Hashmap is better than a list. 

            recievedPackage -> TTL = recievedPackage -> TTL - 1;

        if (recievedPackage -> TTL > 0) {
            makePack(&sendPackage
    */
        if(len == sizeof(pack)) {
          makePack(&sendPackage, TOS_NODE_ID, TOS_NODE_ID, 0, 0, mySeqNum, text, PACKET_MAX_PAYLOAD_SIZE); // List for now
          call Sender.send(sendPackage, AM_BROADCAST_ADDR);

           // makePack(&sendPackage,
           //           TOS_NODE_ID,
           //           recievedPackage -> dest,
           //           recievedPackage -> TTL,
           //           0,
           //           recievedPackage -> seq,
           //           recievedPackage -> payload,
           //           PACKET_MAX_PAYLOAD_SIZE);

           sendWithTimerPing(&sendPackage);

           return msg;
        }

      } else if(recievedPackage -> protocol == 1) {
          returned = 1; //gottem

          if(recievedPackage -> seq == 1) {
              return msg;
          }
          if (currentNeighbors.nodes[recievedPackage -> src] != 1) {
            call Sender.sendPackage(destination);
            currentNeighbors.nodes[recievedPackage -> src] = 1;

          }



sendWithTimerDiscovery(sendPackage, ignoreSelf(recievedPackage -> src + 1))
     }
         dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
         return msg;
   }   

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload) {

      dbg(NEIGHBOR_CHANNEL, "Spinging destinations: %i!\n", (destination));
      call Sender.sendPackage(destination);
      // makePack(&sendPackage,
      // map here?

      seqNum = seqNum + 1;
      sendWithTimerPing(&sendPackage);
   }
// we are not a neighbor
   uint16_t ignoreSelf(uint16_t destination){
     if( TOS_NODE_ID == destination) {
       return destination + 1;
     }

     return destination;
}
   void sendWithTimerDiscovery(pack Package, uint16_t destination) {

     returned = 0;
     lastDestination = destination;
     call packageTimer.startOneShot(1000);
     call Sender.send(Package, destination, src);
   }

   event void packageTimer.fired(){
     if( returned == 0 ) {
       dbg(GENERAL_CHANNEL, "Destination 404 \n");
       lastDestination = lastDestination + 1;
       call Sender.send(sendPackage, lastDestination);
     }
 }

   event void neighborExplorerTimer.fired(){
      pack discMssg;

   event void CommandHandler.printNeighbors(){
       int i = 1;

       while(i < sizeof(currentNeighbors.nodes)) {
           if(currentNeighbors.nodes[i] == 1) {

               dbg(NEIGHBOR_CHANNEL, "Neighbor: %i\n", i);

           }
           i++;
       }
}
    makePack(&sendPackage, TOS_NODE_ID, TOS_NODE_ID, 0, 0, mySeqNum, text, PACKET_MAX_PAYLOAD_SIZE); // List for now

// Another Hashmap WIP

//      while(nodeToDiscover < maxNodeCount) {
//          makePack(&discMssg,
//                   TOS_NODE_ID,
//                   nodeToDiscover,
//                   500,
//                   2,
//                   0,
//                   &currentNeighbors,
//                   PACKET_MAX_PAYLOAD_SIZE);

//         sendWithTimerDiscovery(discMssg, nodeToDiscover);

//         nodeToDiscover++;
//      }
// }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

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