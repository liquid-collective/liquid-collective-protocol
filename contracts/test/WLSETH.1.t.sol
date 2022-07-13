//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/interfaces/IRiverToken.sol";
import "../src/WLSETH.1.sol";
import "./Vm.sol";
import "./utils/UserFactory.sol";

contract RiverTokenMock is IRiverToken {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    uint256 internal underlyingAssetTotal;
    uint256 internal _totalSupply;

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

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(_from == msg.sender || approvals[_from][msg.sender] >= _value, "unauthorized");
        balances[_from] -= _value;
        balances[_to] += _value;
        if (_from != msg.sender) {
            approvals[_from][msg.sender] -= _value;
        }
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
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
}

contract WLSETHV1Tests {
    IRiverToken internal river;
    WLSETHV1 internal wlseth;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    function setUp() external {
        river = new RiverTokenMock();
        wlseth = new WLSETHV1();
        wlseth.initWLSETHV1(address(river));
        RiverTokenMock(address(river)).sudoSetUnderlyingTotal(100 ether);
    }

    function testAlreadyInitialized() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        wlseth.initWLSETHV1(address(river));
    }

    function testTokenName() external view {
        assert(keccak256(bytes(wlseth.name())) == keccak256("Wrapped Alluvial Ether"));
    }

    function testTokenSymbol() external view {
        assert(keccak256(bytes(wlseth.symbol())) == keccak256("wlsETH"));
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
            balance = wlseth.balanceOf(_guy);
            vm.startPrank(_guy);
            wlseth.burn(_guy, balance);
            assert(wlseth.totalSupply() == 0 ether);
            balance = wlseth.balanceOf(_guy);
            balance = RiverTokenMock(address(river)).balanceOf(_guy);
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
        balance = wlseth.balanceOf(_guy);
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
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.totalSupply() == 6.25 ether);
        wlseth.burn(_guy, balance / 16);
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
            balance = wlseth.balanceOf(_guy);
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
        balance = wlseth.balanceOf(_guy);
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
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.balanceOf(_guy) == 6.25 ether);
        wlseth.burn(_guy, balance / 16);
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

        balance = wlseth.balanceOf(_guy);
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
        wlseth.burn(_guy, balance / 16);
        assert(wlseth.balanceOf(_guy) == 3.125 ether);
        wlseth.burn(_guy, balance / 16);
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
            wlseth.mint(_guy, balance);
            vm.stopPrank();
            balance = wlseth.balanceOf(_guy);
            assert(balance == 100 ether);
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

    function testTransfer(
        uint256 _guySalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
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
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, 100 ether);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferTooMuch(
        uint256 _guySalt,
        uint256 _recipientSalt,
        uint32 _sum
    ) external {
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

    function testTransferFrom(
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
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
            assert(wlseth.allowance(_from, _approved) == 0);
            guyBalance = wlseth.balanceOf(_from);
            recipientBalance = wlseth.balanceOf(_recipient);
            assert(guyBalance == 0);
            assert(recipientBalance == 100 ether);
            vm.startPrank(_recipient);
            wlseth.burn(_recipient, 100 ether);
            vm.stopPrank();
            recipientBalance = RiverTokenMock(address(river)).balanceOf(_recipient);
            assert(recipientBalance == _sum);
        }
    }

    function testTransferFromTooMuch(
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
                    "AllowanceTooLow(address,address,uint256,uint256)",
                    _from,
                    _approved,
                    100 ether - 1,
                    100 ether
                )
            );
            wlseth.transferFrom(_from, _recipient, 100 ether);
            vm.stopPrank();
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
}