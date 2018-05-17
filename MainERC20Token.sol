pragma solidity ^ 0.4.23;

import "https://github.com/liulanblock/contract/blob/master/ERCToken.sol";
import "https://github.com/liulanblock/contract/blob/master/State.sol";

contract MainERC20Token is ERCToken(0), State {

    bytes32  public  symbol;
    uint256  public  decimals = 18; // standard token precision. override to customize

    constructor(bytes32 symbol_) public{
      symbol = symbol_;
    }

    function transfer(address dst, uint wad) stoppable public returns (bool) {
        return super.transfer(dst, wad);
    }
    function transferFrom (address src, address dst, uint wad ) stoppable public returns (bool) {
        return super.transferFrom(src, dst, wad);
    }
    function approve(address guy, uint wad) stoppable public  returns (bool) {
        return super.approve(guy, wad);
    }

    function push(address dst, uint128 wad) public returns (bool) {
        return transfer(dst, wad);
    }
    function pull(address src, uint128 wad) public returns (bool) {
        return transferFrom(src, msg.sender, wad);
    }
    
    function mint(uint128 wad) onlyOwner stoppable public {
        _balances[msg.sender] = _balances[msg.sender].add(wad);
        _supply = _supply.add(wad);
    }
    function burn(uint128 wad) onlyOwner stoppable public {
        _balances[msg.sender] = _balances[msg.sender].sub(wad);
        _supply = _supply.sub(wad);
    }

    // Optional token name

    bytes32   public  name = "";

    function setName(bytes32 name_) public onlyOwner {
        name = name_;
    }

}
