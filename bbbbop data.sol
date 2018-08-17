pragma solidity ^0.4.24;

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
// import "./StandardToken.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

contract RBAC {
  using Roles for Roles.Role;

  mapping (string => Roles.Role) private roles;

  event RoleAdded(address addr, string roleName);
  event RoleRemoved(address addr, string roleName);

  /**
   * @dev reverts if addr does not have role
   * @param addr address
   * @param roleName the name of the role
   * // reverts
   */
  function checkRole(address addr, string roleName)
    view
    public
  {
    roles[roleName].check(addr);
  }

  /**
   * @dev determine if addr has role
   * @param addr address
   * @param roleName the name of the role
   * @return bool
   */
  function hasRole(address addr, string roleName)
    view
    public
    returns (bool)
  {
    return roles[roleName].has(addr);
  }

  /**
   * @dev add a role to an address
   * @param addr address
   * @param roleName the name of the role
   */
  function addRole(address addr, string roleName)
    internal
  {
    roles[roleName].add(addr);
    emit RoleAdded(addr, roleName);
  }

  /**
   * @dev remove a role from an address
   * @param addr address
   * @param roleName the name of the role
   */
  function removeRole(address addr, string roleName)
    internal
  {
    roles[roleName].remove(addr);
    emit RoleRemoved(addr, roleName);
  }

  /**
   * @dev modifier to scope access to a single role (uses msg.sender as addr)
   * @param roleName the name of the role
   * // reverts
   */
  modifier onlyRole(string roleName)
  {
    checkRole(msg.sender, roleName);
    _;
  }

  /**
   * @dev modifier to scope access to a set of roles (uses msg.sender as addr)
   * @param roleNames the names of the roles to scope access to
   * // reverts
   *
   * @TODO - when solidity supports dynamic arrays as arguments to modifiers, provide this
   *  see: https://github.com/ethereum/solidity/issues/2467
   */
  // modifier onlyRoles(string[] roleNames) {
  //     bool hasAnyRole = false;
  //     for (uint8 i = 0; i < roleNames.length; i++) {
  //         if (hasRole(msg.sender, roleNames[i])) {
  //             hasAnyRole = true;
  //             break;
  //         }
  //     }

  //     require(hasAnyRole);

  //     _;
  // }
}

contract DataContract is Ownable, RBAC{
    string public constant ROLE_CONTROllER = "BussinessContract";

    modifier onlyBussinessContract(){
        checkRole(msg.sender, ROLE_CONTROllER);
        _;
    }

    function removeContract(address currentAddr) public onlyOwner{
        removeRole(currentAddr, ROLE_CONTROllER);
    }

    function setContract(address addr) public onlyOwner{
        require(addr!=address(0));
        addRole(addr, ROLE_CONTROllER);
    }
}

contract BOPUserData is DataContract {
  using SafeMath for uint256;

  bool isLocked;
  address BOTokenContract;
  ERC20Basic BOToken;

  mapping (address => uint256) public balances;
  mapping(address => address) public inviterOf;
  mapping(address => bool) public isRegisted;

  modifier onlyUnlocked(){
      require(!isLocked, 'this contract is locked');
      _;
  }

  event Transfer(address indexed from, address indexed to, uint256 value);
  event LogSetBalance(address addr, uint value);

  function setBOTokenContract(address addr) public onlyOwner {
      BOToken = ERC20Basic(addr);
  }

  function register(address inviter, address invitee) public onlyBussinessContract{
      require(!isRegisted[invitee], 'registed.');
      require(inviterOf[invitee]==address(0), 'inviter already exist.');
      require(inviter != invitee);
      inviterOf[invitee] = inviter;
      isRegisted[invitee] = true;
  }

  function setBalance(address[] addrs, uint[] values) public onlyOwner{
    require(addrs.length == values.length, 'address length not equal to value length.');
    for(uint i=0; i< addrs.length; i++) {
        balances[addrs[i]] = values[i];
        emit LogSetBalance(addrs[i], values[i]);
    }
  }

  function deposit(address addr, uint amount) public onlyBussinessContract {
      balances[addr] = balances[addr].add(amount);
  }

  function withdraw(uint amount) public onlyUnlocked {
    balances[msg.sender] = balances[msg.sender].sub(amount);
    BOToken.transfer(msg.sender, amount);
  }

  function transferFrom(address _from, address _to, uint256 _value) public onlyBussinessContract returns (bool){
    require(_to != address(0));
    require(_value <= balances[_from]);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  function multiTransfer(address[] _froms, address[] _tos, uint256[] _values) public onlyBussinessContract{
    require(_froms.length == _tos.length, 'input array length not equal.');
    require(_tos.length == _values.length, 'input array length not equal.');
    for(uint i = 0; i < _froms.length; i++){
      transferFrom(_froms[i], _tos[i], _values[i]);
    }
  }
}

contract BOPItemData is DataContract {
  using SafeMath for uint256;

  address BOPContract;

  struct item {
      uint balance;
      uint minBalance;
      bool isSettling;
  }

  mapping(uint => item) public items;
  mapping (uint => mapping (address => uint)) public investToItem;

  function getItemBalance(uint itemId) public view returns (uint) {
    return items[itemId].balance;
  }

  function getItemMinBalance(uint itemId) public view returns (uint) {
    return items[itemId].minBalance;
  }

  function getItemSettlingState(uint itemId) public view returns (bool) {
      return items[itemId].isSettling;
  }

  function setItemSettlingState(uint itemId, bool isSettling) public onlyBussinessContract{
      items[itemId].isSettling = isSettling;
  }

  function setInvestToItem(uint itemId, address dealer, uint value) public onlyBussinessContract {
      investToItem[itemId][dealer] = value;
  }

  function changeItemBalance(uint itemId, uint _value, bool isAdd) public onlyBussinessContract{
    if(isAdd){
      items[itemId].balance = items[itemId].balance.add(_value);
    } else {
      require(items[itemId].balance.sub(_value) >= items[itemId].minBalance);
      items[itemId].balance = items[itemId].balance.sub(_value);
    }
  }

  function changeItemMinBalance(uint itemId, uint _value, bool isAdd) public onlyBussinessContract{
    if(isAdd) {
      require(items[itemId].balance >= items[itemId].minBalance.add(_value));
      items[itemId].minBalance = items[itemId].minBalance.add(_value);
    } else {
      items[itemId].minBalance = items[itemId].minBalance.sub(_value);
    }
  }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage role, address addr)
    internal
  {
    role.bearer[addr] = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage role, address addr)
    internal
  {
    role.bearer[addr] = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage role, address addr)
    view
    internal
  {
    require(has(role, addr));
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage role, address addr)
    view
    internal
    returns (bool)
  {
    return role.bearer[addr];
  }
}
