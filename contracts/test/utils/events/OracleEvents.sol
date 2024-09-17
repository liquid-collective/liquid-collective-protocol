//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

/// @title OracleEvents
/// @author Alluvial Finance Inc.
/// @notice Event definitions as emitted by the Oracle contract for testing purposes
contract OracleEvents {
    event SetQuorum(uint256 _newQuorum);
    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event SetMember(address indexed oldAddress, address indexed newAddress);
    event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime);
    event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound);
    event SetRiver(address _river);
    event RewardsEarned(
        address indexed _collector,
        uint256 _oldTotalUnderlyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );
}