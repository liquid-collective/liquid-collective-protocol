//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

// fixtures
import "../fixtures/RiverV1TestBase.sol";
// mocks
import "../mocks/DepositContractMock.sol";
import "../mocks/RiverMock.sol";
// utils
import "../utils/BytesGenerator.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../utils/UserFactory.sol";
// contracts
import "../../src/Allowlist.1.sol";
import "../../src/River.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/Withdraw.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/interfaces/IWLSETH.1.sol";
import "../../src/components/OracleManager.1.sol";
import "../../src/Firewall.sol";
import "../../src/TUPProxy.sol";
import "../components/OracleManager.1.t.sol";

/// @title DeploymentFixture
/// @author Alluvial Finance Inc.
/// @notice Deployment fixture for LC contracts mirroring the hardhat deployment scripts for integration testing.
contract DeploymentFixture is RiverV1TestBase {
    // Constants
    address constant DEPOSIT_CONTRACT = address(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    uint64 constant genesisTimestamp = 1695902400;
    uint256 constant grossFee = 1250;

    // WithdrawV1
    TUPProxy withdrawProxy;

    // AllowlistV1
    Firewall allowlistFirewall;
    Firewall allowlistProxyFirewall;
    TUPProxy allowlistProxy;

    // RiverV1 river;
    Firewall riverFirewall; 
    TUPProxy riverProxy;
    Firewall riverProxyFirewall;

    // OracleV1
    Firewall oracleFirewall; 
    TUPProxy oracleProxy;
    Firewall oracleProxyFirewall;

    // OperatorsRegistryV1
    Firewall operatorsRegistryFirewall; 
    TUPProxy operatorsRegistryProxy; 
    Firewall operatorsRegistryProxyFirewall;

    // ELFeeRecipientV1
    TUPProxy elFeeRecipientProxy;

    // RedeemManagerV1
    Firewall redeemManagerFirewall;
    TUPProxy redeemManagerProxy;

    // CoverageFundV1
    TUPProxy coverageFundProxy;

    // Addresses
    address deployer = address(0x123); // Example address for the deployer
    address governor = address(0x456); // Example address for the governor
    address executor = address(0x789); // Example address for the executor
    address proxyAdministrator = address(0xabc); // Example address for the proxy admin
    address futureOracleAddress;
    address futureOperatorsRegistryAddress;
    address futureELFeeRecipientAddress;
    address futureRiverAddress;
    address futureRedeemManagerAddress;

    function setUp() public override {
        super.setUp();

        // Fund the addresses with Ether for gas fees
        vm.deal(deployer, 10 ether);
        vm.deal(governor, 10 ether);
        vm.deal(executor, 10 ether);
        vm.deal(proxyAdministrator, 10 ether);

        vm.startPrank(deployer);

        // 01 deploy withdraw stub
        deployWithdraw();

        // 02 deploy allowlist
        deployAllowlist();

        // 03 deploy River
        deployRiver();

        // 03 deploy Oracle
        deployOracle();

        // 03 deploy Operators Registry
        deployOperatorsRegistry();

        // 03 deploy EL Fee Recipient
        deployELFeeRecipient();

        // 03 deploy Redeem Manager
        deployRedeemManager();

        // initialize RiverV1_1 + WithdrawV1
        initializations();

        // 04 deploy coverage fund
        deployCoverageFund();

        vm.stopPrank();
    }

    function deployWithdraw() internal {
        withdraw = new WithdrawV1();

        // bytes4[] memory emptyArr = new bytes4[](0);
        bytes memory emptyBytes = new bytes(0);
        withdrawProxy = new TUPProxy(
            address(withdraw), // implementation
            proxyAdministrator, // proxy admin
            emptyBytes // no inititalization
        );
        emit log_named_address("Withdraw deployed at:", address(withdrawProxy));
    }

    // Helper function to deploy the Allowlist
    function deployAllowlist() internal {
        // Compute Allowlist contract address
        address futureAllowlistAddress = computeAddress(deployer, vm.getNonce(deployer) + 3);

        // Deploy Firewall contract
        bytes4[] memory emptyArr= new bytes4[](0);
        allowlistFirewall = new Firewall(governor, executor, futureAllowlistAddress, emptyArr);
        emit log_named_address("AllowlistFirewall deployed at:", address(allowlistFirewall));
        
        // Deploy AllowlistProxyFirewall contract
        allowlistProxyFirewall = deployFirewall(proxyAdministrator, executor, futureAllowlistAddress);

        // Deploy Allowlist contract via proxy
        allowlist = new AllowlistV1();
        allowlistProxy = new TUPProxy(
            address(allowlist), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initAllowlistV1(address,address)", address(allowlistFirewall), address(allower)) // TODO admin, allower 
        );
        emit log_named_address("Allowlist deployed at:", address(allowlistProxy));

        AllowlistV1(address(allowlistProxy)).initAllowlistV1_1(denier);
        require(address(allowlistProxy) == futureAllowlistAddress, "Invalid future address computation");
    }

    /// @notice internal helper to deploy River contract using a TUPProxy and Firewall
    function deployRiver() internal {
        deposit = new DepositContractMock();
        LibImplementationUnbricker.unbrick(vm, address(deposit));

        // Compute future contract addresses
        futureELFeeRecipientAddress = computeAddress(deployer, vm.getNonce(deployer) + 13); // proxy is in 14 txs
        futureOperatorsRegistryAddress = computeAddress(deployer, vm.getNonce(deployer) + 11); // proxy is in 12 txs
        futureOracleAddress = computeAddress(deployer, vm.getNonce(deployer) + 7); // proxy is in 8 txs
        futureRiverAddress = computeAddress(deployer, vm.getNonce(deployer) + 3); // proxy is in 4 txs

        // Deploy Firewall contract
        bytes4[] memory emptyArr= new bytes4[](0);
        riverFirewall = new Firewall(governor, executor, futureRiverAddress, emptyArr);
        emit log_named_address("RiverFirewall deployed at:", address(riverFirewall));
        
        // Deploy RiverProxyFirewall contract
        riverProxyFirewall = deployFirewall(proxyAdministrator, executor, futureRiverAddress);

        // Deploy River contract via proxy;
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1ForceCommittable();
        riverProxy = new TUPProxy(
            address(river), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initRiverV1(address,address,bytes32,address,address,address,address,address,uint256)", 
            address(deposit),
            futureELFeeRecipientAddress,
            withdrawalCredentials,
            futureOracleAddress, 
            address(riverProxyFirewall),
            address(allowlistProxyFirewall),
            futureOperatorsRegistryAddress,
            collector,
            grossFee)
        );
        emit log_named_address("River deployed at:", address(riverProxy));
        require(address(riverProxy) == futureRiverAddress, "Invalid future address computation");
    }

    /// @notice internal helper to deploy Oracle contract using a TUPProxy and Firewall
    function deployOracle() internal {
        assertTrue(futureOracleAddress != address(0), "futureOracleAddress is the null address. Deploy River first.");
        // Deploy Firewall contract
        bytes4[] memory emptyArr= new bytes4[](0);
        oracleFirewall = new Firewall(governor, executor, futureOracleAddress, emptyArr);
        emit log_named_address("OracleFirewall deployed at:", address(oracleFirewall));
        
        // Deploy RiverProxyFirewall contract
        oracleProxyFirewall = deployFirewall(proxyAdministrator, executor, futureOracleAddress);

        // Deploy Oracle contract via proxy
        oracle = new OracleV1();
        oracleProxy = new TUPProxy(
            address(oracle), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initOracleV1(address,address,uint64,uint64,uint64,uint64,uint256,uint256)", 
            address(riverProxyFirewall), address(admin), 225, 32, 12, genesisTimestamp, 1000, 500)
        );
        emit log_named_address("Oracle deployed at:", address(oracleProxy));
        require(address(oracleProxy) == futureOracleAddress, "Invalid future address computation");
    }

    /// @notice internal helper to deploy OperatorsRegistry contract using a TUPProxy and Firewall
    function deployOperatorsRegistry() internal {
        assertTrue(futureOperatorsRegistryAddress != address(0), "futureOracleAddress is the null address. Deploy River first.");
        // Deploy Firewall contract
        bytes4[] memory hashes= new bytes4[](1);
        hashes[0] = bytes4(keccak256("setOperatorLimits"));
        operatorsRegistryFirewall = new Firewall(governor, executor, futureOperatorsRegistryAddress, hashes);
        emit log_named_address("OperatorsRegistryFirewall deployed at:", address(operatorsRegistryFirewall));
        
        // Deploy OpertatorsRegistryProxyFirewall contract
        operatorsRegistryProxyFirewall = deployFirewall(proxyAdministrator, executor, futureOperatorsRegistryAddress);

        // Deploy OperatorsRegistry via proxy
        operatorsRegistry = new OperatorsRegistryWithOverridesV1();
        operatorsRegistryProxy = new TUPProxy(
            address(operatorsRegistry), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initOperatorsRegistryV1(address,address)", 
            address(operatorsRegistryFirewall),address(futureRiverAddress))
        );
        emit log_named_address("OperatorsRegistry deployed at:", address(operatorsRegistryProxyFirewall));
        require(address(operatorsRegistryProxy) == futureOperatorsRegistryAddress, "Invalid future address computation");
    }

    /// @notice internal helper to deploy ELFeeRecipient contract using a TUPProxy
    function deployELFeeRecipient() internal {
        assertTrue(futureELFeeRecipientAddress != address(0), "futureELFeeRecipientAddress is the null address. Deploy River first.");

        elFeeRecipient = new ELFeeRecipientV1();
        elFeeRecipientProxy = new TUPProxy(
            address(elFeeRecipient), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initELFeeRecipientV1(address)", 
            address(futureRiverAddress))
        );
        emit log_named_address("ELFeeRecipient deployed at:", address(elFeeRecipientProxy));
        require(address(elFeeRecipientProxy) == futureELFeeRecipientAddress, "Invalid future address computation");
    }

    function deployRedeemManager() internal {
        futureRedeemManagerAddress = computeAddress(deployer, vm.getNonce(deployer) + 2);

        // Deploy RedeemManagerFirewall contract
        redeemManagerFirewall = deployFirewall(proxyAdministrator, executor, futureRedeemManagerAddress);

        // Deploy Redeem Manager via proxy
        redeemManager = new RedeemManagerV1();
        redeemManagerProxy = new TUPProxy(
            address(redeemManager), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initializeRedeemManagerV1(address)", 
            address(riverProxy))
        );
        emit log_named_address("RedeemManager deployed at:", address(redeemManagerProxy));
        require(address(redeemManagerProxy) == futureRedeemManagerAddress, "Invalid future address computation");
    }

    /// @notice internal helper to initialize RiverV1_1 and WithdrawV1 contracts
    function initializations() internal {
        WithdrawV1(address(withdrawProxy)).initializeWithdrawV1(address(riverProxy));

        RiverV1 proxyAsRiverV1 = RiverV1(payable(address(riverProxy)));
        proxyAsRiverV1.initRiverV1_1(
            address(redeemManagerProxy),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTimestamp,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound,
            minDailyNetCommittableAmount,
            maxDailyRelativeCommittable
        );

        OperatorsRegistryV1 proxyAsOperatorsRegistryV1 = OperatorsRegistryV1(address(operatorsRegistryProxy));
        proxyAsOperatorsRegistryV1.forceFundedValidatorKeysEventEmission(1);
    }

    /// @notice internal helper to deploy coverage fund contract using a TUPProxy
    function deployCoverageFund() internal {
        coverageFund = new CoverageFundV1();
        coverageFundProxy = new TUPProxy(
            address(coverageFund), // implementation
            proxyAdministrator, // proxy admin 
            abi.encodeWithSignature("initCoverageFundV1(address)", 
            address(riverProxy))
        );
        emit log_named_address("CoverageFund deployed at:", address(coverageFundProxy));
    }

    /// @notice internal helper to deploy firewall contract
    /// @dev matches hardhat deployment scripts deployment pattern
    function deployFirewall(address _proxyAdministrator, address _executor, address _futureDeploymentAddress) internal returns(Firewall newContractFirewall) {
        // Deploy Firewall contract
        bytes4[] memory hashes= new bytes4[](1);
        hashes[0] = bytes4(keccak256("pause()"));
        newContractFirewall = new Firewall(_proxyAdministrator, _executor, _futureDeploymentAddress, hashes);
        emit log_named_address("Firewall deployed at:", address(newContractFirewall));
        return newContractFirewall;
    }

    /// @notice Utility function to anticipate the contract address pre-deployment
    function computeAddress(address _deployer, uint nonce) internal pure returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xd6),
            bytes1(0x94),
            _deployer,
            bytes1(uint8(nonce))
        )))));
    }
}

