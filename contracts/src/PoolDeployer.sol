//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {TUPProxy} from "./TUPProxy.sol";
import {Firewall} from "./Firewall.sol";
import {Administrable} from "./Administrable.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {IWithdrawV1} from "./interfaces/IWithdraw.1.sol";
import {IRiverV1} from "./interfaces/IRiver.1.sol";

contract PoolDeployer is Administrable {
    address constant DEPOSIT_CONTRACT = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    bytes32 salt;
    address withdrawImplementation;
    address allowListImplementation;
    address riverImplementation;
    address oracleImplementation;
    address operatorsRegistryImplementation;
    address elFeeRecipientImplementation;
    address coverageFundImplementation;
    address redeemManagerImplementation;
    address firewallImplementation;

    bytes32 allowlistSalt = keccak256(bytes("allowlist"));

    address futureAllowlistAddress;
    address futureELFeeRecipientAddress;
    address futureOperatorsRegistryAddress;
    address futureOracleAddress;
    address futureRiverAddress;
    address futureRedeemManagerAddress;
    address withdraw;
    address allowListFirewall;
    address allowlist;
    address riverFirewall;
    address river;
    address riverProxyFirewall;
    address oracleFirewall;
    address oracle;
    address oracleProxyFirewall;
    address operatorRegistryFirewall;
    address operatorsRegistry;
    address elFeeRecipient;
    address redeemManagerProxyFirewall;
    address coverageFund;
    address redeemManager;

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

    constructor(
        address _admin,
        address _withdrawImplementation,
        address _allowListImplementation,
        address _riverImplementation,
        address _oracleImplementation,
        address _operatorsRegistryImplementation,
        address _elFeeRecipientImplementation,
        address _coverageFundImplementation,
        address _redeemManagerImplementation,
        address _firewallImplementation
    ) {
        _setAdmin(_admin);

        withdrawImplementation = _withdrawImplementation;
        allowListImplementation = _allowListImplementation;
        riverImplementation = _riverImplementation;
        oracleImplementation = _oracleImplementation;
        operatorsRegistryImplementation = _operatorsRegistryImplementation;
        elFeeRecipientImplementation = _elFeeRecipientImplementation;
        coverageFundImplementation = _coverageFundImplementation;
        redeemManagerImplementation = _redeemManagerImplementation;
        firewallImplementation = _firewallImplementation;
    }

    function deployPool(
        address _governor,
        address _proxyAdministrator,
        address _executor,
        InitializePoolParams calldata _poolParams
    ) external {
        bytes memory empty = new bytes(0);
        bytes4[] memory _executorCallableSelectors = new bytes4[](0);

        futureAllowlistAddress = CREATE3.getDeployed(allowlistSalt);
        futureELFeeRecipientAddress = CREATE3.getDeployed(getSalt("EL"));
        futureOperatorsRegistryAddress = CREATE3.getDeployed(getSalt("OR"));
        futureOracleAddress = CREATE3.getDeployed(getSalt("O"));
        futureRiverAddress = CREATE3.getDeployed(getSalt("R"));
        futureRedeemManagerAddress = CREATE3.getDeployed(getSalt("RM"));
        withdraw = address(new TUPProxy(withdrawImplementation, _proxyAdministrator, new bytes(0)));

        allowListFirewall =
            deployFirewall(getSalt("af"), _governor, _executor, futureAllowlistAddress, _executorCallableSelectors);

        allowlist = deployTUPProxy(
            allowlistSalt,
            allowListImplementation,
            allowListFirewall,
            abi.encodeWithSignature("initAllowlistV1(address,address)", allowListFirewall, allowListFirewall)
        );

        _executorCallableSelectors = new bytes4[](1);
        _executorCallableSelectors[0] = bytes4(abi.encode("0x13d86aed")); //depositToConsensusLayer

        _executorCallableSelectors = new bytes4[](1);
        _executorCallableSelectors[0] = bytes4(abi.encode("0x16f6f03e")); // removeMember
        oracleFirewall =
            deployFirewall(getSalt("OF"), _governor, _executor, futureOracleAddress, _executorCallableSelectors);

        oracle = deployTUPProxy(
            getSalt("O"),
            oracleImplementation,
            _proxyAdministrator,
            abi.encodeWithSignature(
                "initOracleV1(address,address,uint64,uint64,uint64,uint64,uint256,uint256)",
                futureRiverAddress,
                oracleFirewall,
                _poolParams._epochsPerFrame,
                _poolParams._slotsPerEpoch,
                _poolParams._secondsPerSlot,
                _poolParams._genesisTime,
                _poolParams._annualAprUpperBound,
                _poolParams._relativeLowerBound
            )
        );

        _executorCallableSelectors = new bytes4[](0);
        oracleProxyFirewall =
            deployFirewall(getSalt("OPF"), _proxyAdministrator, _executor, oracle, _executorCallableSelectors);

        _executorCallableSelectors = new bytes4[](3);
        _executorCallableSelectors[0] = bytes4(abi.encode("0x5a16f135")); // setOperatorStatus
        _executorCallableSelectors[0] = bytes4(abi.encode("0x39251321")); // setOperatorName
        _executorCallableSelectors[0] = bytes4(abi.encode("0x354454c5")); // setOperatorLimits
        operatorRegistryFirewall = deployFirewall(
            getSalt("ORF"), _governor, _executor, futureOperatorsRegistryAddress, _executorCallableSelectors
        );

        operatorsRegistry = deployTUPProxy(
            getSalt("OR"),
            operatorsRegistryImplementation,
            _proxyAdministrator,
            abi.encodeWithSignature(
                "initOperatorsRegistryV1(address,address)", operatorRegistryFirewall, futureRiverAddress
            )
        );

        elFeeRecipient = deployTUPProxy(
            getSalt("EL"),
            elFeeRecipientImplementation,
            _proxyAdministrator,
            abi.encodeWithSignature("initELFeeRecipientV1(address)", futureRiverAddress)
        );

        riverFirewall =
            deployFirewall(getSalt("RF"), _governor, _executor, futureRiverAddress, _executorCallableSelectors);

        riverProxyFirewall = deployFirewall(
            getSalt("RPF"), _proxyAdministrator, _executor, futureRiverAddress, _executorCallableSelectors
        );

        river = deployTUPProxy(
            getSalt("R"),
            riverImplementation,
            riverProxyFirewall,
            abi.encodeWithSignature(
                "initRiverV1(address,address,bytes32,address,address,address,address,address,uint256)",
                DEPOSIT_CONTRACT,
                futureELFeeRecipientAddress,
                IWithdrawV1(withdraw).getCredentials(),
                futureOracleAddress,
                riverFirewall,
                allowlist,
                futureOperatorsRegistryAddress,
                _poolParams._collectorAddress,
                _poolParams._globalFee
            )
        );

        IRiverV1(payable(river)).initRiverV1_1(
            futureRedeemManagerAddress,
            _poolParams._epochsPerFrame,
            _poolParams._slotsPerEpoch,
            _poolParams._secondsPerSlot,
            _poolParams._genesisTime,
            _poolParams._epochsToAssumedFinality,
            _poolParams._annualAprUpperBound,
            _poolParams._relativeLowerBound,
            _poolParams._minDailyNetCommittableAmount_,
            _poolParams._maxDailyRelativeCommittableAmount_
        );

        _executorCallableSelectors = new bytes4[](1);
        _executorCallableSelectors[0] = bytes4(abi.encode("0x5a16f135")); // pause
        redeemManagerProxyFirewall =
            deployFirewall(getSalt("RMF"), _governor, _executor, futureRedeemManagerAddress, _executorCallableSelectors);

        redeemManager = deployTUPProxy(
            getSalt("RM"),
            redeemManagerImplementation,
            redeemManagerProxyFirewall,
            abi.encodeWithSignature("initializeRedeemManagerV1(address)", river)
        );
        coverageFund = deployTUPProxy(
            getSalt("CF"),
            coverageFundImplementation,
            _proxyAdministrator,
            abi.encodeWithSignature("initCoverageFundV1(address)", river)
        );
    }

    function getSalt(string memory _saltSeed) internal returns (bytes32) {
        return keccak256(bytes(_saltSeed));
    }

    function deployFirewall(
        bytes32 _salt,
        address _governor,
        address _executor,
        address _destination,
        bytes4[] memory _executorCallableSelectors
    ) internal returns (address) {
        return CREATE3.deploy(
            _salt,
            abi.encodePacked(
                type(Firewall).creationCode, abi.encode(_governor, _executor, _destination, _executorCallableSelectors)
            ),
            0
            );
    }

    function deployTUPProxy(bytes32 _salt, address _implementation, address _admin, bytes memory data)
        internal
        returns (address deployment)
    {
        deployment = CREATE3.deploy(
            _salt, abi.encodePacked(type(TUPProxy).creationCode, abi.encode(_implementation, _admin, data)), 0
        );
    }

    function initializePool() external {}
}
