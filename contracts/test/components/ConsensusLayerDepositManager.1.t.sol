//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../OperatorAllocationTestBase.sol";
import "../../src/components/ConsensusLayerDepositManager.1.sol";
import "../utils/LibImplementationUnbricker.sol";

import "../mocks/DepositContractMock.sol";

contract ConsensusLayerDepositManagerV1ExposeInitializer is ConsensusLayerDepositManagerV1 {
    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    ) external {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        _setKeeper(address(0x1));
    }

    function setKeeper(address _keeper) external {
        _setKeeper(_keeper);
    }

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }

    function _incrementFundedETH(uint256[] memory) internal override {}

    function _updateFundedValidatorsFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}
}

contract ConsensusLayerDepositManagerV1InitTests is Test {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    event SetDepositContractAddress(address indexed depositContract);
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);

    function testDepositContractEvent() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));

        vm.expectEmit(true, true, true, true);
        emit SetDepositContractAddress(address(depositContract));
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testWithdrawalCredentialsEvent() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        vm.expectEmit(true, true, true, true);
        emit SetWithdrawalCredentials(withdrawalCredentials);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }
}
