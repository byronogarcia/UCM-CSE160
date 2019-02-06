#define AM_FORWARDING 81

configuration ForwarderC{
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
}

implementation{
	components ForwarderP;
	components new SimpleSendC(AM_FORWARDING);
	components new AMReceiverC(AM_FORWARDING);
	
	components RoutingTableC;
	ForwarderP.RoutingTable -> RoutingTableC.RoutingTable;

	ForwarderP.Sender -> SimpleSendC;
	ForwarderP.InternalReceiver -> AMReceiverC;

	MainReceive = ForwarderP.MainReceive;
	SimpleSend = ForwarderP.ForwardSender;


}
	
