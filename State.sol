pragma solidity ^0.4.23;
import "https://github.com/liulanblock/contract/blob/master/Ownable.sol"

contract State is Ownable {

    bool public stopped;

    modifier stoppable {
        assert (!stopped);
        _;
    }
    function stop() public onlyOwner {
        stopped = true;
    }
    function start() public onlyOwner {
        stopped = false;
    }

}
