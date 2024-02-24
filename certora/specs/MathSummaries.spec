import "CVLMath.spec";

methods {
    //function math.mulDiv(uint256 a, uint256 b, uint256 c) internal returns (uint256) => mulDivDeterministic(a, b, c);
    //function math.mulDiv(uint256 a, uint256 b, uint256 c) internal returns (uint256) => mulDivArbitrary(a, b, c);
    //function math.mulDiv(uint256 a, uint256 b, uint256 c) internal returns (uint256) => mulDivDownAbstractPlus(a, b, c);
}

ghost mulDivArbitrary(uint256, uint256, uint256) returns uint256;
ghost mapping(uint256 => mapping(uint256 => uint256)) _mulDivGhost;

function mulDivDeterministic(uint256 x, uint256 y, uint256 z) returns uint256 {
    require z !=0;
    uint256 xy = require_uint256(x * y);
    require _mulDivGhost[xy][z] <= xy;
    require y <= z => _mulDivGhost[xy][z] <= x;
    require x <= z => _mulDivGhost[xy][z] <= y;
    require y == z => _mulDivGhost[xy][z] == x;
    require x == z => _mulDivGhost[xy][z] == y;
    return _mulDivGhost[xy][z];
}