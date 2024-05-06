//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {PoolDeployer} from "./../src/PoolDeployer.sol";

contract PoolDeployerTest is Test {
    PoolDeployer poolDeployer;
    address _governor = makeAddr("GOVERNOR");
    address _proxyAdministrator = makeAddr("PA");
    address _executor = makeAddr("Executor");

    address withdrawImplementation = 0xCD859343d6C95E3791B389b63225794DB98e7F6C;
    address allowListImplementation = 0xCfa8cf872f0B8cE15C175a8eB13688D5c69E9CEe;
    address riverImplementation = 0x48D93d8C45Fb25125F13cdd40529BbeaA97A6565;
    address oracleImplementation = 0x485ade5B7f66ECcaD4583862bc5c2Aa838720aA0;
    address operatorsRegistryImplementation = 0x99Dd9F8D3a62cb416f6ef5ABBC90185c4162f8d0;
    address elFeeRecipientImplementation = 0x108A04f7A181A1e0A58Bdb1772707aEe88294e13;
    address coverageFundImplementation = 0x6B747258A0E926De1F5C2a54Fe92514706Cce2D4;
    address redeemManagerImplementation = 0x423CE5282c460EED5FE0786B4D47d2c2a4Ef3721;
    address firewallImplementation = 0xF1b958564edF538dDa1302D3D81eB58eE204B87F;

    struct InitializePoolParams {
        uint256 _globalFee;
        address _collectorAddress;
        uint64 _epochsPerFrame;
        uint64 _slotsPerEpoch;
        uint64 _secondsPerSlot;
        uint64 _genesisTime;
        uint64 _epochsToAssumedFinality;
        uint256 _annualAprUpperBound;
        uint256 _relativeLowerBound;
        uint128 _minDailyNetCommittableAmount_;
        uint128 _maxDailyRelativeCommittableAmount_;
    }

    function setUp() external {
        // try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
        // vm.createFork(vm.envString("MAINNET_FORK_RPC_URL"));
        // console.log("Fork is active");
        // } catch {
        //     _skip = true;
        // }
        poolDeployer = new PoolDeployer(
            address(this),
            withdrawImplementation,
            allowListImplementation,
            riverImplementation,
            oracleImplementation,
            operatorsRegistryImplementation,
            elFeeRecipientImplementation,
            coverageFundImplementation,
            redeemManagerImplementation,
            firewallImplementation
        );
    }

    function testDeploy() external {
        PoolDeployer.InitializePoolParams memory params = PoolDeployer.InitializePoolParams({
            _globalFee: 1000,
            _collectorAddress: makeAddr("collector"),
            _epochsPerFrame: 225,
            _slotsPerEpoch: 32,
            _secondsPerSlot: 12,
            _genesisTime: 1606824023,
            _epochsToAssumedFinality: 1000,
            _annualAprUpperBound: 1000,
            _relativeLowerBound: 10000,
            _minDailyNetCommittableAmount_: 10000,
            _maxDailyRelativeCommittableAmount_: 1000
        });
        poolDeployer.deployPool(_governor, _proxyAdministrator, _executor, params);
    }
}
