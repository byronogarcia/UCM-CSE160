#include "../interfaces/listInfo.h"
// Custom Interface
interface NeighborDiscovery{
	command void start();
	command void print();
	command neighborTableS* getNeighborList();
	command uint16_t getNeighborListSize();
}
