#include "../interfaces/listInfo.h"

interface RoutingTable{
	command void start();
	command void print();
	command uint16_t getNextHop(uint16_t dest);
}
