//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/WLSETH.1.sol";

contract AllowlistMock {
    mapping(address => bool) internal denied;

    function isDenied(address _account) external view returns (bool) {
        return denied[_account];
    }

    function sudoSetDenied(address _account, bool _isDenied) external {
        denied[_account] = _isDenied;
    }
}

contract RiverTokenMock {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    uint256 internal underlyingAssetTotal;
    uint256 internal _totalSupply;
    bool internal retVal = true;
    address internal allowlistAddr;

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalUnderlyingSupply() external view returns (uint256) {
        return underlyingAssetTotal;
    }

    function balanceOf(address _owner) external view returns (uint256 balance) {
        return balances[_owner];
    }

    function balanceOfUnderlying(address _owner) external view returns (uint256 balance) {
        if (_totalSupply == 0) {
            return 0;
        }
        return (balances[_owner] * underlyingAssetTotal) / _totalSupply;
    }

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256) {
        if (_totalSupply == 0) {
            return 0;
        }
        return (shares * underlyingAssetTotal) / _totalSupply;
    }

    function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256) {
        if (underlyingAssetTotal == 0) {
            return 0;
        }
        return (underlyingBalance * _totalSupply) / underlyingAssetTotal;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(_from == msg.sender || approvals[_from][msg.sender] >= _value, "unauthorized");
        balances[_from] -= _value;
        balances[_to] += _value;
        if (_from != msg.sender) {
            approvals[_from][msg.sender] -= _value;
        }
        return retVal;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return retVal;
    }

    function approve(address _spender, uint256 _value) external {
        approvals[msg.sender][_spender] = _value;
    }

    function sudoSetUnderlyingTotal(uint256 _total) external {
        underlyingAssetTotal = _total;
    }

    function sudoSetBalance(address _who, uint256 _amount) external {
        if (balances[_who] > _amount) {
            _totalSupply -= (balances[_who] - _amount);
        } else {
            _totalSupply += (_amount - balances[_who]);
        }
        balances[_who] = _amount;
    }

    function sudoSetRetVal(bool _newVal) external {
        retVal = _newVal;
    }

    function getAllowlist() external view returns (address) {
        return allowlistAddr;
    }

    function sudoSetAllowlist(address _allowlist) external {
        allowlistAddr = _allowlist;
    }
}

abstract contract WLSETHV1TestBase is Test {
    IRiverV1 internal river;
    WLSETHV1 internal wlseth;
    AllowlistMock internal allowlistMock;
    UserFactory internal uf = new UserFactory();

    event Mint(address indexed _recipient, uint256 _value);
    event Burn(address indexed _recipient, uint256 _value);
    event SetRiver(address indexed river);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
}

contract WLSETHV1InitializationTests is WLSETHV1TestBase {
    function setUp() external {
        allowlistMock = new AllowlistMock();
        river = IRiverV1(payable(address(new RiverTokenMock())));
        RiverTokenMock(address(river)).sudoSetAllowlist(address(allowlistMock));
        wlseth = new WLSETHV1();
        LibImplementationUnbricker.unbrick(vm, address(wlseth));
    }

    function testInitialization() external {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        wlseth.initWLSETHV1(address(river));
    }
}

contract WLSETHV1Tests is WLSETHV1TestBase {
    function setUp() external {
        allowlistMock = new AllowlistMock();
        river = IRiverV1(payable(address(new RiverTokenMock())));
        RiverTokenMock(address(river)).sudoSetAllowlist(address(allowlistMock));
        wlseth = new WLSETHV1();
        LibImplementationUnbricker.unbrick(vm, address(wlseth));
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        wlseth.initWLSETHV1(address(river));
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(100 ether);
    }

    function testAlreadyInitialized() external {
        vm.expectRevert("Initializable: contract is already initialized");
        wlseth.initWLSETHV1(address(river));
    }

    function testTokenName() external view {
        assert(keccak256(bytes(wlseth.name())) == keccak256("Wrapped Liquid Staked ETH"));
    }

    function testTokenSymbol() external view {
        assert(keccak256(bytes(wlseth.symbol())) == keccak256("wLsETH"));
    }

    function testTokenDecimals() external view {
        assert(wlseth.decimals() == 18);
    }

    function testTotalSupplyEdits(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            assert(wlseth.totalSupply() == 0);
            wlseth.mint(_guy, balance);
            assert(wlseth.totalSupply() == 100 ether);
            vm.stopPrank();
            balance = wlseth.sharesOf(_guy);
            vm.startPrank(_guy);
            wlseth.burn(_guy, balance);
            assert(wlseth.totalSupply() == 0 ether);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 0);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testTotalSupplyEditsMultiBurnsAndRebase(uint256 _guySalt) external {
        address _guy = uf._new(_guySalt);
        uint256 _sum = 10.1 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);
        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        assert(wlseth.totalSupply() == 0);
        wlseth.mint(_guy, balance);
        assert(wlseth.totalSupply() == 100 ether);
        vm.stopPrank();
        balance = wlseth.sharesOf(_guy);
        vm.startPrank(_guy);
        wlseth.burn(_guy, balance / 2);
        assert(wlseth.totalSupply() == 50 ether);
        wlseth.burn(_guy, balance / 4);
        assert(wlseth.totalSupply() == 25 ether);
        wlseth.burn(_guy, balance / 8);
        assert(wlseth.totalSupply() == 12.5 ether);
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.totalSupply() == 6.25 ether);
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);
        assert(wlseth.totalSupply() == 12.5 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.totalSupply() == 6.25 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.totalSupply() == 0);
        balance = wlseth.balanceOf(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);
        vm.stopPrank();
    }

    function testBalanceOfEdits(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            assert(wlseth.balanceOf(_guy) == 0);
            wlseth.mint(_guy, balance);
            assert(wlseth.balanceOf(_guy) == 100 ether);
            vm.stopPrank();
            balance = wlseth.sharesOf(_guy);
            vm.startPrank(_guy);
            wlseth.burn(_guy, balance);
            assert(wlseth.balanceOf(_guy) == 0 ether);
            balance = wlseth.balanceOf(_guy);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testBalanceOfEditsMultiBurnsAndRebase(uint256 _guySalt) external {
        address _guy = uf._new(_guySalt);
        uint256 _sum = 10.1 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);
        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        assert(wlseth.balanceOf(_guy) == 0);
        wlseth.mint(_guy, balance);
        assert(wlseth.balanceOf(_guy) == 100 ether);
        vm.stopPrank();
        balance = wlseth.sharesOf(_guy);
        vm.startPrank(_guy);
        wlseth.burn(_guy, balance / 2);
        assert(wlseth.balanceOf(_guy) == 50 ether);
        wlseth.burn(_guy, balance / 4);
        assert(wlseth.balanceOf(_guy) == 25 ether);
        wlseth.burn(_guy, balance / 8);
        assert(wlseth.balanceOf(_guy) == 12.5 ether);
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.balanceOf(_guy) == 6.25 ether);
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);
        assert(wlseth.balanceOf(_guy) == 12.5 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.balanceOf(_guy) == 6.25 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.balanceOf(_guy) == 0);
        balance = wlseth.balanceOf(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);
        vm.stopPrank();
    }

    function testBalanceOfEditsMultiBurnsMultiUserAndRebase(uint256 _guySalt, uint256 _otherGuySalt) external {
        address _guy = uf._new(_guySalt);
        address _otherGuy = uf._new(_otherGuySalt);
        uint256 _sum = 10.1 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        RiverTokenMock(address(river)).sudoSetBalance(_otherGuy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);

        vm.startPrank(_otherGuy);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        assert(wlseth.balanceOf(_otherGuy) == 0);
        wlseth.mint(_otherGuy, balance);
        assert(wlseth.balanceOf(_otherGuy) == 50 ether);
        vm.stopPrank();

        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        assert(wlseth.balanceOf(_guy) == 0);
        wlseth.mint(_guy, balance);
        assert(wlseth.balanceOf(_guy) == 50 ether);
        vm.stopPrank();

        balance = wlseth.sharesOf(_guy);
        vm.startPrank(_guy);
        wlseth.burn(_guy, balance / 2);
        assert(wlseth.balanceOf(_guy) == 25 ether);
        wlseth.burn(_guy, balance / 4);
        assert(wlseth.balanceOf(_guy) == 12.5 ether);
        wlseth.burn(_guy, balance / 8);
        assert(wlseth.balanceOf(_guy) == 6.25 ether);
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.balanceOf(_guy) == 3.125 ether);
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);
        assert(wlseth.balanceOf(_guy) == 6.25 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.balanceOf(_guy) == 3.125 ether);
        wlseth.burn(_guy, balance / 32);
        assert(wlseth.balanceOf(_guy) == 0);
        balance = wlseth.balanceOf(_guy);
        balance = RiverTokenMock(address(river)).balanceOf(_guy);
        vm.stopPrank();
    }

    function testMintWrappedTokens(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            vm.expectEmit(true, true, true, true);
            emit Mint(_guy, balance);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
        } else {
            assert(balance == 0 ether);
        }
    }

    function testMintWrappedTokensCheckTransfer(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), _guy, 100 ether);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
        } else {
            assert(balance == 0 ether);
        }
    }

    function testMintWrappedTokensInvalidTransfer(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            RiverTokenMock(address(river)).sudoSetRetVal(false);
            vm.expectRevert(abi.encodeWithSignature("TokenTransferError()"));
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = wlseth.balanceOf(_guy);
            assert(balance == 0 ether);
        } else {
            assert(balance == 0 ether);
        }
    }

    function _mint(address _who, uint256 _sum) internal {
        RiverTokenMock(address(river)).sudoSetBalance(_who, RiverTokenMock(address(river)).balanceOf(_who) + _sum);
        vm.startPrank(_who);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        wlseth.mint(_who, _sum);
        vm.stopPrank();
    }

    function testSendingToContractDoesntIncreaseSupply(uint256 _guySalt, uint256 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        vm.startPrank(_guy);
        RiverTokenMock(address(river)).transfer(address(wlseth), _sum);
        vm.stopPrank();
        assert(wlseth.totalSupply() == 0);
    }

    function testTransfer(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_guy);
            wlseth.transfer(_recipient, 100 ether);
            vm.stopPrank();
            guyBalance = wlseth.balanceOf(_guy);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            recipientBalance = wlseth.sharesOf(_recipient);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, recipientBalance);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromMsgSender(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            vm.startPrank(_guy);
            vm.expectRevert(
                abi.encodeWithSignature("AllowanceTooLow(address,address,uint256,uint256)", _guy, _guy, 0, 100 ether)
            );
            wlseth.transferFrom(_guy, _recipient, 100 ether);
        }
    }

    function testTransferZero(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _guy, address(0)));
            vm.prank(_guy);
            wlseth.transfer(address(0), guyBalance);
        }
    }

    function testTransferTooMuch(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
            wlseth.transfer(_recipient, 100 ether + 1);
            vm.stopPrank();
        }
    }

    function testApprove(uint256 _fromSalt, uint256 _approvedSalt, uint32 _sum) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 100 ether);
        }
    }

    function testApproveZero(uint256 _fromSalt, uint32 _sum) external {
        address _from = uf._new(_fromSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
            wlseth.approve(address(0), 100 ether);
            vm.stopPrank();
        }
    }

    function testTransferFrom(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 100 ether);
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 0);
            guyBalance = wlseth.balanceOf(_from);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            recipientBalance = wlseth.sharesOf(_recipient);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, recipientBalance);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromToZeroAddress(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 100 ether);
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _from, address(0)));
            wlseth.transferFrom(_from, address(0), 100 ether);
            vm.stopPrank();
        }
    }

    function testTransferFromUnlimitedAllowance(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, type(uint256).max);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == type(uint256).max);
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == type(uint256).max);
            guyBalance = wlseth.balanceOf(_from);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            uint256 recipientShares = wlseth.sharesOf(_recipient);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, recipientShares);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromAfterIncreasedAllowance(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.increaseAllowance(_approved, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 100 ether);
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 0);
            guyBalance = wlseth.balanceOf(_from);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            uint256 recipientShares = wlseth.sharesOf(_recipient);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, recipientShares);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromAfterIncreasedAndDecreasedAllowance(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.increaseAllowance(_approved, 50 ether);
            wlseth.increaseAllowance(_approved, 200 ether);
            wlseth.decreaseAllowance(_approved, 150 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 100 ether);
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 0);
            guyBalance = wlseth.balanceOf(_from);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            uint256 recipientShares = wlseth.sharesOf(_recipient);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, recipientShares);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromTooMuch(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum)
        external
    {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, 100 ether);
            vm.stopPrank();
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
            wlseth.transferFrom(_from, _recipient, 100 ether + 1);
            vm.stopPrank();
        }
    }

    function testTransferFromApprovalTooLow(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            vm.startPrank(_from);
            wlseth.approve(_approved, 100 ether - 1);
            vm.stopPrank();
            uint256 guyBalance = wlseth.balanceOf(_from);
            uint256 recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 100 ether);
            assert(recipientBalance == 0);
            vm.startPrank(_approved);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)", _from, _approved, 100 ether - 1, 100 ether
                )
            );
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
        }
    }

    function testBurnWrappedTokensInvalidTransfer(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == 0);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
            balance = wlseth.sharesOf(_guy);
            RiverTokenMock(address(river)).sudoSetRetVal(false);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("TokenTransferError()"));
            wlseth.burn(_guy, balance);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testBurnWrappedTokens(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == 0);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
            balance = wlseth.sharesOf(_guy);
            vm.startPrank(_guy);
            vm.expectEmit(true, true, true, true);
            emit Burn(_guy, balance);
            wlseth.burn(_guy, balance);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 0);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testBurnWrappedTokensCheckTransfer(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == 0);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
            balance = wlseth.sharesOf(_guy);
            vm.startPrank(_guy);
            vm.expectEmit(true, true, true, true);
            emit Transfer(_guy, address(0), 100 ether);
            wlseth.burn(_guy, balance);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 0);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testBurnWrappedTokensWithRebase(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == 0);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
            RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 200 ether);
            balance = wlseth.sharesOf(_guy);
            vm.startPrank(_guy);
            wlseth.burn(_guy, balance);
            balance = wlseth.balanceOf(_guy);
            assert(balance == 0);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testBurnFail() external {
        vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
        wlseth.burn(address(this), 100);
    }

    function testMintWrappedTokensTooMuch(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
        uint256 balance = river.balanceOfUnderlying(_guy);
        if (_sum > 0) {
            assert(balance == 100 ether);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
            assert(balance == _sum);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), balance);
            vm.expectRevert("unauthorized");
            wlseth.mint(_guy, balance + 1);
            vm.stopPrank();
        } else {
            assert(balance == 0 ether);
        }
    }

    function testMintTransferEventEmitsUnderlyingAfterRebase(uint256 _guySalt) external {
        address _guy = uf._new(_guySalt);
        // sudoSetBalance sets _guy's balance AND updates totalSupply
        // So if we set balance to 50 shares, totalSupply becomes 50
        // With underlyingTotal = 100 ether, ratio is 2:1 (underlying:shares)
        // Thus 50 shares = 100 ether underlying
        uint256 shares = 50 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, shares);

        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);

        // Transfer event should emit underlying value (100 ether), not shares (50 ether)
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _guy, 100 ether);
        wlseth.mint(_guy, shares);
        vm.stopPrank();

        // Verify the Mint event still emits shares
        assert(wlseth.sharesOf(_guy) == shares);
        assert(wlseth.balanceOf(_guy) == 100 ether);
    }

    function testBurnTransferEventEmitsUnderlyingAfterRebase(uint256 _guySalt) external {
        address _guy = uf._new(_guySalt);
        uint256 shares = 100 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, shares);

        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);
        wlseth.mint(_guy, shares);
        vm.stopPrank();

        // Simulate rebase: 2:1 underlying:shares ratio
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);

        uint256 sharesToBurn = 50 ether;
        // Transfer event should emit underlying value (100 ether), not shares (50 ether)
        vm.startPrank(_guy);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_guy, address(0), 100 ether);
        wlseth.burn(_guy, sharesToBurn);
        vm.stopPrank();
    }

    function testTransferEventEmitsUnderlyingValue(uint256 _guySalt, uint256 _recipientSalt) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        uint256 shares = 100 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, shares);

        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);
        wlseth.mint(_guy, shares);
        vm.stopPrank();

        // Simulate rebase: 2:1 underlying:shares ratio
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);
        uint256 guyBalance = wlseth.balanceOf(_guy);
        assert(guyBalance == 200 ether);

        // Transfer 100 ether (underlying), which is 50 shares at 2:1 ratio
        vm.startPrank(_guy);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_guy, _recipient, 100 ether);
        wlseth.transfer(_recipient, 100 ether);
        vm.stopPrank();

        assert(wlseth.balanceOf(_guy) == 100 ether);
        assert(wlseth.balanceOf(_recipient) == 100 ether);
    }

    function testTransferFromEventEmitsUnderlyingValue(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt)
        external
    {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        uint256 shares = 100 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_from, shares);

        vm.startPrank(_from);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);
        wlseth.mint(_from, shares);
        vm.stopPrank();

        // Simulate rebase: 2:1 underlying:shares ratio
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(200 ether);

        vm.prank(_from);
        wlseth.approve(_approved, 100 ether);

        // Transfer 100 ether (underlying) via transferFrom
        vm.startPrank(_approved);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _recipient, 100 ether);
        wlseth.transferFrom(_from, _recipient, 100 ether);
        vm.stopPrank();

        assert(wlseth.balanceOf(_from) == 100 ether);
        assert(wlseth.balanceOf(_recipient) == 100 ether);
    }

    function testTransferEmitsZeroWhenValueTooSmallForShares(uint256 _guySalt, uint256 _recipientSalt) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        uint256 shares = 100 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_guy, shares);

        vm.startPrank(_guy);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);
        wlseth.mint(_guy, shares);
        vm.stopPrank();

        // Set up ratio where small underlying amounts don't convert to shares
        // underlyingTotal = 1000 ether, totalSupply = 100 ether
        // sharesFromUnderlyingBalance(1 wei) = (1 * 100 ether) / 1000 ether = 0
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(1000 ether);

        // User has 1000 ether balance now, try to transfer 1 wei
        // This converts to 0 shares, so Transfer event emits 0
        vm.startPrank(_guy);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_guy, _recipient, 0);
        wlseth.transfer(_recipient, 1);
        vm.stopPrank();

        // Balances unchanged since 0 shares transferred
        assert(wlseth.balanceOf(_recipient) == 0);
    }

    function testTransferFromEmitsZeroWhenValueTooSmallForShares(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        uint256 shares = 100 ether;
        RiverTokenMock(address(river)).sudoSetBalance(_from, shares);

        vm.startPrank(_from);
        RiverTokenMock(address(river)).approve(address(wlseth), shares);
        wlseth.mint(_from, shares);
        vm.stopPrank();

        // Set up ratio where small underlying amounts don't convert to shares
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(1000 ether);

        vm.prank(_from);
        wlseth.approve(_approved, 1);

        // Transfer 1 wei via transferFrom, converts to 0 shares
        vm.startPrank(_approved);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _recipient, 0);
        wlseth.transferFrom(_from, _recipient, 1);
        vm.stopPrank();

        // Balances unchanged since 0 shares transferred
        assert(wlseth.balanceOf(_recipient) == 0);
        assert(wlseth.sharesOf(_recipient) == 0);
        assert(wlseth.sharesOf(_from) == 100 ether);
        assert(wlseth.balanceOf(_from) == 1000 ether);
    }
}

contract WLSETHV1DenyTests is WLSETHV1TestBase {
    function setUp() external {
        allowlistMock = new AllowlistMock();
        river = IRiverV1(payable(address(new RiverTokenMock())));
        RiverTokenMock(address(river)).sudoSetAllowlist(address(allowlistMock));
        wlseth = new WLSETHV1();
        LibImplementationUnbricker.unbrick(vm, address(wlseth));
        wlseth.initWLSETHV1(address(river));
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(100 ether);
    }

    function _mint(address _who, uint256 _sum) internal {
        RiverTokenMock(address(river)).sudoSetBalance(_who, RiverTokenMock(address(river)).balanceOf(_who) + _sum);
        vm.startPrank(_who);
        RiverTokenMock(address(river)).approve(address(wlseth), _sum);
        wlseth.mint(_who, _sum);
        vm.stopPrank();
    }

    function testTransferDeniedSender(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            allowlistMock.sudoSetDenied(_guy, true);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _guy));
            wlseth.transfer(_recipient, guyBalance);
            vm.stopPrank();
        }
    }

    function testTransferDeniedRecipient(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            allowlistMock.sudoSetDenied(_recipient, true);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _recipient));
            wlseth.transfer(_recipient, guyBalance);
            vm.stopPrank();
        }
    }

    function testTransferFromDeniedSender(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum)
        external
    {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            uint256 balance = wlseth.balanceOf(_from);
            vm.prank(_from);
            wlseth.approve(_approved, balance);
            allowlistMock.sudoSetDenied(_from, true);
            vm.startPrank(_approved);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _from));
            wlseth.transferFrom(_from, _recipient, balance);
            vm.stopPrank();
        }
    }

    function testTransferFromDeniedRecipient(
        uint256 _fromSalt,
        uint256 _approvedSalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
        address _from = uf._new(_fromSalt);
        address _approved = uf._new(_approvedSalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_from, _sum);
            uint256 balance = wlseth.balanceOf(_from);
            vm.prank(_from);
            wlseth.approve(_approved, balance);
            allowlistMock.sudoSetDenied(_recipient, true);
            vm.startPrank(_approved);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _recipient));
            wlseth.transferFrom(_from, _recipient, balance);
            vm.stopPrank();
        }
    }

    function testTransferSucceedsWhenNotDenied(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            vm.startPrank(_guy);
            wlseth.transfer(_recipient, guyBalance);
            vm.stopPrank();
            assert(wlseth.balanceOf(_guy) == 0);
            assert(wlseth.balanceOf(_recipient) == guyBalance);
        }
    }

    function testBurnDeniedSender(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 shares = wlseth.sharesOf(_guy);
            allowlistMock.sudoSetDenied(_guy, true);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _guy));
            wlseth.burn(_guy, shares);
            vm.stopPrank();
        }
    }

    function testBurnDeniedRecipient(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 shares = wlseth.sharesOf(_guy);
            allowlistMock.sudoSetDenied(_recipient, true);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _recipient));
            wlseth.burn(_recipient, shares);
            vm.stopPrank();
        }
    }

    function testMintDeniedSender(uint256 _guySalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        if (_sum > 0) {
            RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
            allowlistMock.sudoSetDenied(_guy, true);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _guy));
            wlseth.mint(_guy, _sum);
            vm.stopPrank();
        }
    }

    function testMintDeniedRecipient(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            RiverTokenMock(address(river)).sudoSetBalance(_guy, _sum);
            allowlistMock.sudoSetDenied(_recipient, true);
            vm.startPrank(_guy);
            RiverTokenMock(address(river)).approve(address(wlseth), _sum);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _recipient));
            wlseth.mint(_recipient, _sum);
            vm.stopPrank();
        }
    }

    function testTransferSucceedsAfterUndeny(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external {
        address _guy = uf._new(_guySalt);
        address _recipient = uf._new(_recipientSalt);
        if (_sum > 0) {
            _mint(_guy, _sum);
            uint256 guyBalance = wlseth.balanceOf(_guy);
            allowlistMock.sudoSetDenied(_guy, true);
            vm.startPrank(_guy);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _guy));
            wlseth.transfer(_recipient, guyBalance);
            vm.stopPrank();
            allowlistMock.sudoSetDenied(_guy, false);
            vm.startPrank(_guy);
            wlseth.transfer(_recipient, guyBalance);
            vm.stopPrank();
            assert(wlseth.balanceOf(_guy) == 0);
            assert(wlseth.balanceOf(_recipient) == guyBalance);
        }
    }
}
