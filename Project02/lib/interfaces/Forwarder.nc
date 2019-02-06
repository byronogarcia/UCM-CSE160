interface Forwarder{

	command error_t send(pack msg, uint16_t dest);
}
