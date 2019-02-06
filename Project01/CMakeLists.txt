cmake_minimum_required(VERSION 3.9)
project(CSE160_Project_Skeleton_Code_master)

set(CMAKE_CXX_STANDARD 11)

add_executable(CSE160_Project_Skeleton_Code_master
        dataStructures/interfaces/Hashmap.nc
        dataStructures/interfaces/List.nc
        dataStructures/modules/HashmapC.nc
        dataStructures/modules/ListC.nc
        includes/am_types.h
        includes/channels.h
        includes/command.h
        includes/CommandMsg.h
        includes/packet.h
        includes/protocol.h
        includes/sendInfo.h
        includes/socket.h
        lib/interfaces/CommandHandler.nc
        lib/interfaces/SimpleSend.nc
        lib/interfaces/Transport.nc
        lib/modules/CommandHandlerC.nc
        lib/modules/CommandHandlerP.nc
        lib/modules/SimpleSendC.nc
        lib/modules/SimpleSendP.nc
        noise/no_noise.txt
        topo/example.topo
        topo/long_line.topo
        topo/topo.txt
        CommandMsg.py
        Makefile
        Node.nc
        NodeC.nc
        packet.py
        pingTest.py
        README.md
        TestSim.py)
