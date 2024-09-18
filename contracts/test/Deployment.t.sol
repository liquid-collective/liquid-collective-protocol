// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverV1TestBase.sol";
import "./fixtures/DeploymentFixture.sol";
// mocks
import "./mocks/DepositContractMock.sol";
import "./mocks/RiverMock.sol";
// utils
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
// contracts
import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/Oracle.1.sol";
import "../src/Withdraw.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/RedeemManager.1.sol";
import "../src/CoverageFund.1.sol";
import "../src/interfaces/IWLSETH.1.sol";
import "../src/components/OracleManager.1.sol";
import "../src/Firewall.sol";
import "../src/TUPProxy.sol";
import "./components/OracleManager.1.t.sol";

contract DeploymentTest is Test, DeploymentFixture {
    /// @notice Test that the deployment setup is as intended
    function testAssertCorrectDeployment(uint256 _salt) public {
        // Withdraw
        // check withdraw
        assertEq(WithdrawV1(address(withdrawProxy)).getRiver(), address(riverProxy), "Withdraw: river contract incorrectly set");
        // Allowlist
        // check allowlist firewall
        assert(address(allowlistFirewall) != address(0));
        assertEq(allowlistFirewall.executor(), executor, "AllowlistFirewall: executor address mismatch");
        // check allowlist proxy
        assert(address(allowlistProxyFirewall) != address(0));
        assertEq(allowlistProxyFirewall.executor(), executor, "AllowlistProxyFirewall: executor address mismatch");
        // check allowlist roles
        assertEq(AllowlistV1(address(allowlistProxy)).getAllower(), allower, "Allowlist: allower incorrectly set");
        assertEq(AllowlistV1(address(allowlistProxy)).getDenier(), denier, "Allowlist: denier incorrectly set");

        // River
        // check River deployed correctly
        address riverAllowlist = RiverV1(payable(address(riverProxy))).getAllowlist();
        assertEq(address(riverAllowlist), address(allowlistProxy), "River: allowlist incorrectly set");

        address riverOracle = OracleManagerV1(payable(address(riverProxy))).getOracle(); // should return proxy
        assertTrue(riverOracle == address(oracleProxy), "River: oracle incorrectly set.");
        assertTrue(OracleManagerV1(payable(address(riverProxy))).getOracle() == address(oracleProxy), "River: oracle incorrectly set.");
    }
}