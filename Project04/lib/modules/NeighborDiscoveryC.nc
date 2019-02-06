// Configuration
#define AM_NEIGHBOR 62

configuration NeighborDiscoveryC{
	provides interface NeighborDiscovery;
}

implementation{
	components NeighborDiscoveryP;
	components new TimerMilliC() as beaconTimer;
	components new SimpleSendC(AM_NEIGHBOR);
	components new AMReceiverC(AM_NEIGHBOR);
	
	// External Wiring
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

	// Internal Wiring
	NeighborDiscoveryP.NeighborSender -> SimpleSendC;
	NeighborDiscoveryP.MainReceive -> AMReceiverC;
	NeighborDiscoveryP.beaconTimer -> beaconTimer;

} 
