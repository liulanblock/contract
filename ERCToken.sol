pragma solidity ^ 0.4.23;

import "https://github.com/liulanblock/contract/blob/master/SafeMath.sol";

contract ERC20 {
    function totalSupply() constant public returns (uint supply);
    function balanceOf( address who ) constant public returns (uint value);
    function allowance( address owner, address spender ) constant public returns (uint _allowance);

    function transfer( address to, uint value) public returns (bool ok);
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint value ) public returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}

contract ERCToken is ERC20 {
    using SafeMath for uint;
    uint                                            _supply;
    mapping (address => uint)                       _balances;
    mapping (address => mapping (address => uint))  allowed;

    constructor(uint supply) public {
      _balances[msg.sender] = supply;
      _supply = supply;
    }

    function totalSupply() constant public returns (uint) {
        return _supply;
    }
    function balanceOf(address whoes) constant public returns (uint) {
        return _balances[whoes];
    }
    function allowance(address _owner, address _spender) public constant returns (uint){
      return allowed[_owner][_spender];
    }

    function transfer(address _tos, uint _vals) public returns (bool) {
        require(_balances[msg.sender] >= _vals);

        _balances[msg.sender] = _balances[msg.sender].sub(_vals);
        _balances[_tos] = _balances[_tos].add(_vals);

        emit Transfer(msg.sender, _tos, _vals);

        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        require(_balances[_from] >= _value);
        require(allowed[_from][msg.sender] >= _value);

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);

         emit Transfer(_from, _to, _value);

        return true;
    }

    function approve(address _spender, uint _spenval) public returns (bool) {
        allowed[msg.sender][_spender] = _spenval;

         emit Approval(msg.sender, _spender, _spenval);

        return true;
    }

}
