pragma solidity ^0.4.24;
/* import "./bop.sol"; */
import "./BOPData.sol";


contract Operatable is Ownable, RBAC{
    string public constant ROLE_CONTROllER = "controller";

    modifier onlyController(){
        checkRole(msg.sender, ROLE_CONTROllER);
        _;
    }

    function removeController(address currentController) public onlyOwner{
        removeRole(currentController, ROLE_CONTROllER);
    }

    function setController(address controller) public onlyOwner{
        require(controller!=address(0));
        addRole(controller, ROLE_CONTROllER);
    }
}

contract BOPPlayerCore is Operatable{
    using SafeMath for uint;

    address platform;
    uint public inviteRewardForFirst;
    uint  public inviteRewardForSecond;
    uint public betFeeRate;


    uint constant RATE_ACCURACY = 10000;

    struct BetTicket{
        address player;
        uint amount;
        uint payout;
        uint startTime;
        uint option;
    }

    struct SettleRecord{
        uint result;
        uint settleTime;
        uint leftScore; //whatever it takes to compare;
        uint rightScore;
        bool isSettled;
    }

    BOPUserData users;
    BOPItemData items;

    // mapping(uint => uint) maxTicketId;
    mapping(uint => BetTicket[]) betTickets;
    mapping(uint => mapping (uint => SettleRecord)) settleRecords;

    event LogBetTicket(uint indexed itemId, address indexed player, uint indexed stastartTime, uint ticketId, uint amount, uint payout);
    event LogDeposit(address addr, uint amount);
    event LogRegistration(address inviter, address invitee);
    event LogSettle(address player,uint ticketId, uint result);

    constructor(address _balanceRef, address _itemRef) public {
      users = BOPUserData(_balanceRef);
      items = BOPItemData(_itemRef);
    }

    function platformConfig(address plat) public onlyController{
      platform = plat;
    }

    /* function gameConfig(uint minInvest, ) */

    function register(address inviter, address invitee) public onlyController{
        users.register(inviter, invitee);
        emit LogRegistration(invitee, inviter);
    }

    function deposit(address addr, uint amount) public onlyController{
        users.deposit(addr, amount);
        emit LogDeposit(addr, amount);
    }

    function bet(uint itemId, address player, uint amount, uint payout, uint startTime, uint option) public onlyController{
        require(users.balances(player) >= amount);
        uint ticketId = betTickets[itemId].push(BetTicket(player, amount, payout, startTime, option)).sub(1);
        // maxTicketId[itemId] = maxTicketId[itemId].add(1);
        uint platformFee = amount.mul(betFeeRate).div(RATE_ACCURACY);
        uint actualToItemAmount = amount.sub(platformFee);
        users.transferFrom(player, address(users), platformFee);
        if(users.inviterOf(player)!=address(0)){
            address Inviter = users.inviterOf(player);
            uint reward = amount.mul(inviteRewardForFirst).div(RATE_ACCURACY);
            users.transferFrom(player, Inviter, reward);
            actualToItemAmount = actualToItemAmount.sub(reward);
            if(users.inviterOf(Inviter)!=address(0)){
                Inviter = users.inviterOf(Inviter);
                reward = amount.mul(inviteRewardForSecond).div(RATE_ACCURACY);
                users.transferFrom(player, Inviter, reward);
                actualToItemAmount = actualToItemAmount.sub(reward);
            }
        }
        items.changeItemMinBalance(itemId, payout, true);
        items.changeItemBalance(itemId, actualToItemAmount, true);
        users.transferFrom(player, address(users), actualToItemAmount);
        emit LogBetTicket(itemId, player, startTime, ticketId, amount, payout);
    }

    function settle(uint itemId, uint ticketId, uint leftScore, uint rightScore) public onlyController {
        require(betTickets[itemId][ticketId].player != address(0));
        require(!settleRecords[itemId][ticketId].isSettled);
        uint result;
        if(leftScore > rightScore) {
            result = 1;
        }else if(leftScore < rightScore) {
            result = 2;
        }
        settleRecords[itemId][ticketId] = SettleRecord(result, now, leftScore, rightScore, true);
        items.changeItemMinBalance(itemId, betTickets[itemId][ticketId].payout, false);
        if(result == 0){
            items.changeItemBalance(itemId, betTickets[itemId][ticketId].amount, false);
            users.transferFrom(address(users), betTickets[itemId][ticketId].player, betTickets[itemId][ticketId].amount);
        } else {
            if(betTickets[itemId][ticketId].option == result){
                items.changeItemBalance(itemId, betTickets[itemId][ticketId].payout, false);
                users.transferFrom(address(users), betTickets[itemId][ticketId].player, betTickets[itemId][ticketId].payout);
            }
        }
        emit LogSettle(betTickets[itemId][ticketId].player,ticketId, result);
    }

}

contract BOPDealerCore is Operatable{
    using SafeMath for uint;

    address platform;
    uint dealerFee;
    uint minInvestAmount = 10000000000000;

    BOPUserData users;
    BOPItemData items;

    struct settleRecord {
      uint amount;
      bool willCashOut;
      uint period; //表示清算周期
    }

    // mapping (address => mapping (uint => mapping (bool => settleRecord))) public investToItem;
    mapping (uint => mapping (address => uint)) public setttledPeriod;
    mapping (uint => mapping (address => uint)) public investWaiting;
    mapping (uint => mapping (address => bool)) public willCashOut;
    mapping (uint => uint) principal;  //记利润本金
    mapping (uint => uint) currentPeriod;
    // mapping (uint => bool) isSettling;
    mapping (uint => uint) dealerAmount;
    mapping (uint => uint) settleAmount;

    event LogSettleDealerBalancesOfItem(address indexed dealer, uint indexed itemId, uint newBalance);
    event LogDealerCashOut(uint indexed itemId, address indexed dealer, uint amount);
    event LogDealerCashIn(uint indexed itemId, address indexed dealer, uint amount);
    event LogSwitchCashOut(uint indexed itemId, address indexed dealer, bool isCashingOut);
    event LogchargeToItem(address player,uint itemId,uint vlaues);
    event LogwithdrawFromItem(address player,uint itemId,uint values);
    event LogsettleBegin(uint itemId);
    event LogsettleFinished(uint itemId);

    constructor(address _userRef, address _itemRef) public {
      users = BOPUserData(_userRef);
      items = BOPItemData(_itemRef);
    }

    function investConfigure(uint minInvest, uint dealerfee) public onlyController{
      dealerFee = dealerfee;
      minInvestAmount = minInvest;
    }

    function platformConfigure(address plat) public {
      platform = plat;
    }

    function withdrawFromItem(uint itemId, uint value) public {
        require(!items.getItemSettlingState(itemId));
        investWaiting[itemId][msg.sender] = investWaiting[itemId][msg.sender].sub(value);
        users.transferFrom(address(users), msg.sender, value);
        emit LogwithdrawFromItem(msg.sender,itemId,value);
    }

    function chargeToItem(uint itemId, uint value) public {
        require(!items.getItemSettlingState(itemId));
        require(users.balances(msg.sender) >= value, 'balance not enough');
        require(investWaiting[itemId][msg.sender].add(value).add(items.investToItem(itemId, msg.sender)) > minInvestAmount);
        users.transferFrom(msg.sender, platform, dealerFee);
        investWaiting[itemId][msg.sender] = investWaiting[itemId][msg.sender].add(value-dealerFee);
        users.transferFrom(msg.sender, address(users), value-dealerFee);
        emit LogchargeToItem(msg.sender,itemId,value);
    }

    function switchCashOutState(uint itemId) public {
        require(!items.getItemSettlingState(itemId),' is settling');
        require(items.investToItem(itemId, msg.sender) > 0, 'no balance');
        willCashOut[itemId][msg.sender] = !willCashOut[itemId][msg.sender];
        emit LogSwitchCashOut(itemId, msg.sender, willCashOut[itemId][msg.sender]);
    }

    function settleBegin(uint itemId) public onlyController {
        require(!items.getItemSettlingState(itemId),' is settling');
        items.setItemSettlingState(itemId, true);
        settleAmount[itemId] = 0;
        emit LogsettleBegin(itemId);
    }

    function settleBalancesOfItem(uint itemId, address[] dealers) public onlyController {//退出也要结算，防止大单亏损跑路
      require(items.getItemSettlingState(itemId), 'settlement not begin');
      for(uint i=0; i<dealers.length; i++) {
          require(items.investToItem(itemId, msg.sender) > 0, 'no balance');
          require(setttledPeriod[itemId][dealers[i]] != currentPeriod[itemId], 'already settled');
          items.setInvestToItem(itemId, dealers[i], items.getItemBalance(itemId).mul(items.investToItem(itemId, msg.sender)).div(principal[itemId]));
          setttledPeriod[itemId][dealers[i]] = currentPeriod[itemId];
          settleAmount[itemId] = settleAmount[itemId].add(1);
          emit LogSettleDealerBalancesOfItem(dealers[i], itemId, items.investToItem(itemId, msg.sender));
      }
    }

    function addNewDealer(uint itemId, address[] dealers) public onlyController {
        require(items.getItemSettlingState(itemId), 'settlement not begin');
        require(settleAmount[itemId] == dealerAmount[itemId], 'not all dealer have settled');
        for(uint i = 0; i< dealers.length; i++) {
            cashIntoItem(itemId, dealers[i]);
        }
    }

    function cashIntoItem(uint itemId, address dealer) public onlyController{
        uint cashInAmount = investWaiting[itemId][dealer];
        require(cashInAmount > 0);
        items.changeItemBalance(itemId, cashInAmount, true);
        investWaiting[itemId][dealer] = 0;
        uint newInvestAmount = 0;
        if(items.investToItem(itemId, dealer) == 0) {
            dealerAmount[itemId] = dealerAmount[itemId].add(1);
            settleAmount[itemId] = settleAmount[itemId].add(1);
            newInvestAmount = items.investToItem(itemId, dealer);
        }
        items.setInvestToItem(itemId, dealer, newInvestAmount+cashInAmount);
        setttledPeriod[itemId][dealer] = currentPeriod[itemId];
        willCashOut[itemId][dealer] = false;
        emit LogDealerCashIn(itemId, dealer, cashInAmount);
    }

    function removeCashOutDealer(uint itemId, address[] dealers) public onlyController {
        require(items.getItemSettlingState(itemId), 'settlement not begin');
        require(settleAmount[itemId] == dealerAmount[itemId], 'not all dealer have settled');
        for(uint i=0; i< dealers.length; i++) {
            if(willCashOut[itemId][dealers[i]]) {
                cashOutFromItem(itemId, dealers[i]);
            }
        }
    }

    function cashOutFromItem(uint itemId, address dealer)  public onlyController {
        uint cashOutAmount = items.investToItem(itemId, msg.sender);
        require(cashOutAmount > 0);
        items.changeItemBalance(itemId, cashOutAmount, false);
        users.transferFrom(address(users), dealer, cashOutAmount);
        items.setInvestToItem(itemId, dealer, 0);
        dealerAmount[itemId] = dealerAmount[itemId].sub(1);
        settleAmount[itemId] = settleAmount[itemId].sub(1);
        emit LogDealerCashOut(itemId, dealer, cashOutAmount);
    }

    function settleFinished(uint itemId) public onlyController {
        require(items.getItemSettlingState(itemId), 'settlement not begin');
        require(settleAmount[itemId] == dealerAmount[itemId], 'not all dealer have settled');
        principal[itemId] = items.getItemBalance(itemId);
        currentPeriod[itemId] = currentPeriod[itemId].add(1);
        items.setItemSettlingState(itemId, false);
        emit LogsettleFinished(itemId);
    }
}
