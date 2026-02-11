// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/RedeemManager.1.sol";
import "./mocks/MockERC20.sol";
import "../src/Allowlist.1.sol";

import "./utils/LibImplementationUnbricker.sol";

interface IRedeemManagerV1Mock {
    /// @notice Thrown when a transfer error occured with LsETH
    error TransferError();
}

contract RedeemManagerV1Mock is RedeemManagerV1 {
    // The error we are testing for
    function redeem(uint256 _lsETHAmount) external onlyRedeemerOrRiver {
        if (!_castedRiver().transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
    }
}

contract RiverMock is MockERC20 {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    address internal allowlist;
    uint256 internal rate = 1e18;
    uint256 internal _totalSupply;

    constructor(address _allowlist) MockERC20("Mock River", "MRIV", 18) {
        allowlist = _allowlist;
    }

    function approve(address to, uint256 amount) public virtual override returns (bool) {
        approvals[msg.sender][to] = amount;
        return true;
    }

    error ApprovedAmountTooLow();

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (transferFromFail) {
            return false;
        }
        if (approvals[from][msg.sender] < amount) {
            revert ApprovedAmountTooLow();
        }
        if (approvals[from][msg.sender] != type(uint256).max) {
            approvals[from][msg.sender] -= amount;
        }
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return balances[account];
    }

    /// @notice Sets the balance of the given account and updates totalSupply
    /// @param account The account to set the balance of
    /// @param amount Amount to set as balance
    function sudoDeal(address account, uint256 amount) external {
        if (amount > balances[account]) {
            _totalSupply += amount - balances[account];
        } else {
            _totalSupply -= balances[account] - amount;
        }
        balances[account] = amount;
    }

    function sudoSetRate(uint256 newRate) external {
        rate = newRate;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }

    function sudoReportWithdraw(address redeemManager, uint256 lsETHAmount) external payable {
        RedeemManagerV1(redeemManager).reportWithdraw{value: msg.value}(lsETHAmount);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function totalUnderlyingSupply() external view returns (uint256) {
        return (_totalSupply * rate) / 1e18;
    }

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256) {
        return (shares * rate) / 1e18;
    }

    function pullExceedingEth(address redeemManager, uint256 amount) external {
        RedeemManagerV1(redeemManager).pullExceedingEth(amount);
    }

    fallback() external payable {}
    receive() external payable {}
}

contract RedeemManagerTest is Test {
    RedeemManagerV1Mock internal redeemManager;
    AllowlistV1 internal allowlist;
    RiverMock internal river;
    address internal allowlistAdmin;
    address internal allowlistAllower;
    address internal allowlistDenier;
    address public mockRiverAddress;

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1Mock();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function testTransferError() public {
        // make the transferFrom fail
        river.setTransferFromFail(true);

        vm.expectRevert(IRedeemManagerV1Mock.TransferError.selector);
        vm.prank(address(river));
        redeemManager.redeem(100 ether);
    }
}
