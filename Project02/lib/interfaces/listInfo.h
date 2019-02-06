#ifndef LISTINFO_H
#define LISTINFO_H

typedef struct neighborTableS{
	uint16_t node;
	uint16_t age;
}neighborTableS;

typedef struct routingTableS{
	uint16_t dest;
	uint16_t nextHop;
	uint16_t cost;
	uint16_t age;
}routingTableS;

#endif
