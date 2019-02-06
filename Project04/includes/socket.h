#ifndef __SOCKET_H__
#define __SOCKET_H__

#define CLOSED 0
#define LISTEN 1
#define ESTABLISHED 2
#define SYN_SENT 3
#define SYN_RCVD 4

enum{
	MAX_NUM_OF_SOCKETS = 10,
	ROOT_SOCKET_ADDR = 255,
	ROOT_SOCKET_PORT = 255,
	SOCKET_BUFFER_SIZE = 128,
};

/*enum socket_state{
	CLOSED,
	LISTEN,
	ESTABLISHED,
	SYN_SENT,
	SYN_RCVD,
};*/

typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;

typedef nx_struct socket_addr_t{
	nx_socket_port_t port;
	nx_uint16_t addr;
}socket_addr_t;

//typedef uint8_t socket_t;

typedef struct socket_t{
	uint8_t flag;
	//enum socket_state state;
	uint8_t state;
	//socket_port_t src;
	socket_addr_t src;
	socket_addr_t dest;

	uint8_t sendBuff[SOCKET_BUFFER_SIZE];
	uint8_t lastWritten;
	uint8_t lastAck;
	uint8_t lastSent;
	
	uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
	uint8_t lastRead;
	uint8_t lastRcvd;
	uint8_t nextExpected;
	uint8_t seq;

	uint16_t RTT;
	uint8_t effectiveWindow;
}socket_t;
#endif
