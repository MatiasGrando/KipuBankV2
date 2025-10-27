// SPDX-License-Identifier: MIT
pragma solidity >0.8.28;

/**
* @title Contract KipuBank
* @author Matias Grando - student of EThKipu
* @notice first contract of proyect Ethereum Developer
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract  KipuBank {
    ///@notice immutable variable for the max withdraft per transaction permitted
    uint256 immutable public MAX_WITHDRAFT_PER_TRANSACTION;
    ///@notice immutable variable for the balance cap of bank permitted
    uint256 immutable public MAX_CAP_BANK;
    IERC20 immutable USDC;
    ///@notice variable to record the deposit count
    uint256 public totalDeposits;
    ///@notice variable to record the withdraft count
    uint256 public totalWithdraft;
    AggregatorV3Interface internal  oracle;

    ///@notice map to store user balances
    mapping (address => uint256) private userBalance;

    ///@notice event to register withdrawals 
    event Withdraf(address indexed user, uint256 amount);
    ///@notice event to register deposits
    event Deposit(address indexed user, uint256 amount);

    ///@notice catches the error when the bank's cap is exceeded
    error MaxCapBank(uint256 deposit, uint256 balanceBank, uint256 maxCapBank,address user);
    ///@notice catches the error when the max withdraft per transaction is exceeded
    error MaxWithdraftPerTransaction(uint256 amount,uint256 withdraft,address user);
    ///@notice catches the error when withdraft fail
    error WithdraftFail (bytes error);
    ///@notice catches the error when without sufficient balance for withdraft
    error WithoutSufficientBalance(uint256 amount, uint256 balance);

    /***
    *@notice deploy the contract and initialize variables
    *@dev decalres immutables variables for difine the permissions
    *@param recive two uint256 parameters of variables for initialize, _maxWithdraftPerTransaction nad  _maxCapBank
    */
    constructor(uint256 _maxWithdraftPerTransaction, uint256  _maxCapBank, address _USDC){ 
        MAX_WITHDRAFT_PER_TRANSACTION = _maxWithdraftPerTransaction;
        MAX_CAP_BANK = _maxCapBank;
        USDC=IERC20(_USDC);

    }

    //@dev check if exceeds the maximum of the bank cap
    modifier maxCapBank (uint256 amount){
        if((address(this).balance + amount) > MAX_CAP_BANK) revert MaxCapBank(msg.value, address(this).balance, MAX_CAP_BANK,msg.sender);
        _;
    }
    //@dev check if exceeds the maximum of the withdraft
    modifier maxWithdraft(uint256 amount){
        if(amount> MAX_WITHDRAFT_PER_TRANSACTION) revert MaxWithdraftPerTransaction(amount, MAX_WITHDRAFT_PER_TRANSACTION,msg.sender);
        _;
    }
    
    //@dev check if this has enough balance
    modifier withoutSufficientBalance (uint256 amount){
        uint256 balance = userBalance[msg.sender];
        if(amount > balance) revert WithoutSufficientBalance (amount, balance);
        _;
    }

    //@notice function to deposit ether into the contract
    //@dev first check if it exceeds the maximum of the bank cap
    fallback() external payable maxCapBank(msg.value){ 
        unchecked{
            userBalance[msg.sender] += msg.value;
        }
        _registerOfDeposit();
        emit Deposit(msg.sender, msg.value);
    }

    //@notice function to deposit ether into the contract
    //@dev first check if it exceeds the maximum of the bank cap
    receive() external payable maxCapBank(msg.value){
        unchecked{
            userBalance[msg.sender] += msg.value;
        }
        _registerOfDeposit();
        emit Deposit(msg.sender, msg.value);
    }
    //@notice function to deposit ether into the contract
    //@dev first check if it exceeds the maximum of the bank cap
    function deposit() external payable maxCapBank(msg.value){
        unchecked{
            userBalance[msg.sender] += msg.value;
        }
        _registerOfDeposit();
        emit Deposit(msg.sender, msg.value);
    } 
    
    //@notice function to withdraw ether from the contract
    //@dev first check if have balance and if pass the max of withdraft and just then continuous
    //@param amount the amount to withdraw
    function withdraf(uint256 amount) external maxWithdraft(amount) withoutSufficientBalance(amount) returns(bytes memory data ) {
        unchecked{
            userBalance[msg.sender] -= amount;
        }
        emit Withdraf(msg.sender, amount);
        data= _withdraft(msg.sender, amount);
        _registerOfWithdraft();
        return data;
    }
    function setFeed(address _oracle) external {
        oracle = AggregatorV3Interface(_oracle); //0x694AA1769357215DE4FAC081bf1f309aDC325306 eth/usd
    }
    function getEthPrice () view external returns (int256 _price){
        (, int256 price,,,) = oracle.latestRoundData();
        _price = price;
    }
     ///@notice Withdraw user balance from contract
     //@param amount and user address for  withdraft
    function _withdraft(address user, uint256 amount) private returns (bytes memory) {
        (bool success, bytes memory data)=user.call{value: amount}("");
        if(!success) revert WithdraftFail(data);
        return data;
    }
     ///@notice increases the record of total deposits
    function _registerOfDeposit() private {
        ++totalDeposits;
    }
    ///@notice increases the record of total withdrawals
    function _registerOfWithdraft() private{
        ++totalWithdraft;
    }

     ///@notice return the balance of the user
    function getBalance() external view returns (uint256) {
        return userBalance[msg.sender];
    }
     ///@notice return the balance of the contract
    function getContractBalance () external view returns (uint256 _balance) {
        return address(this).balance;
    }
    
}


----------------------------------------------------------------
// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Coin is ERC20 {
    constructor()
        ERC20("Coin", "USDC")
    {}

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
