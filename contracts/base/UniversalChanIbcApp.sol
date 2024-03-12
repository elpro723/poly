//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import '@open-ibc/vibc-core-smart-contracts/contracts/Ibc.sol';
import '@open-ibc/vibc-core-smart-contracts/contracts/IbcReceiver.sol';
import '@open-ibc/vibc-core-smart-contracts/contracts/IbcDispatcher.sol';
import '@open-ibc/vibc-core-smart-contracts/contracts/IbcMiddleware.sol';

// UniversalChanIbcApp is a contract that can be used as a base contract 
// for IBC-enabled contracts that send packet over the universal channel.
contract UniversalChanIbcApp is IbcMwUser, IbcUniversalPacketReceiver {
    struct UcPacketWithChannel {
        bytes32 channelId;
        UniversalPacket packet;
    }

    struct UcAckWithChannel {
        bytes32 channelId;
        UniversalPacket packet;
        AckPacket ack;
    }

    // received packet as chain B
    UcPacketWithChannel[] public recvedPackets;
    // received ack packet as chain A
    UcAckWithChannel[] public ackPackets;
    // received timeout packet as chain A
    UcPacketWithChannel[] public timeoutPackets;

    constructor(address _middleware) IbcMwUser(_middleware) {}

    function updateMiddleware(address _middleware) external onlyOwner {
        mw = _middleware;
    }

    function sendUniversalPacket(
        address destPortAddr, 
        bytes32 channelId, 
        bytes calldata message, 
        uint64 timeoutTimestamp
    ) external virtual {
        IbcUniversalPacketSender(mw).sendUniversalPacket(
            channelId,
            Ibc.toBytes32(destPortAddr),
            message,
            timeoutTimestamp
        );
    }

    function onRecvUniversalPacket(
        bytes32 channelId,
        UniversalPacket calldata packet
    ) external virtual onlyIbcMw returns (AckPacket memory ackPacket) {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));
        // do logic
        // below is an example, the actual ackpacket data should be implemented by the contract developer
        return AckPacket(true, abi.encodePacked(address(this), Ibc.toAddress(packet.srcPortAddr), 'ack-', packet.appData));
    }

    function onUniversalAcknowledgement(
        bytes32 channelId,
        UniversalPacket memory packet,
        AckPacket calldata ack
    ) external virtual onlyIbcMw {
        // verify packet's destPortAddr is the ack's first encoded address. assumes the packet's destPortAddr is the address of the contract that sent the packet
        // check onRecvUniversalPacket for the encoded ackpacket data
        require(ack.data.length >= 20, 'ack data too short');
        address ackSender = address(bytes20(ack.data[0:20]));
        require(Ibc.toAddress(packet.destPortAddr) == ackSender, 'ack address mismatch');
        ackPackets.push(UcAckWithChannel(channelId, packet, ack));
        // do logic
    }

    function onTimeoutUniversalPacket(bytes32 channelId, UniversalPacket calldata packet) external virtual onlyIbcMw {
        timeoutPackets.push(UcPacketWithChannel(channelId, packet));
        // do logic
    }
}
