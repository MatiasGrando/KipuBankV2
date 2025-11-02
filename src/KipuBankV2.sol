// SPDX-License-Identifier: MIT
pragma solidity >0.8.28;

/**
* @title Contract KipuBank
* @author Matias Grando - student of EThKipu
* @notice first contract of proyect Ethereum Developer
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract  KipuBankV2 is Ownable {

    /*///////////////////////
    Variables
    ///////////////////////*/

    ///@notice immutable variable for the max withdraft in USDC per transaction permitted
    uint256 immutable public MAX_WITHDRAFT_PER_TRANSACTION;
    ///@notice immutable variable for the balance cap in USDC of bank permitted
    uint256 immutable public MAX_CAP_BANK;
    ///@notice immutable variable for the address of the USDC token
    IERC20 immutable USDC;
    ///@notice immutable variable for the decimal of the ETH/USD. wei-18Decimals + oracle 8decimals
    uint256 constant DECIMAL_ETHUSD = 1 * 10 ** 20;
    ///@notice variable to record the deposit count
    uint256 public totalDeposits;
    ///@notice variable to record the withdraft count
    uint256 public totalWithdraft;
    ///@notice variable to store the Chainlink Feed address
    AggregatorV3Interface internal priceFeed;



    /*///////////////////////
    Mapping
    ///////////////////////*/

    /**
     * @notice Stores the token or ETH balances for each user.
     * @dev 
     * - The outer key (`user`) represents the user's wallet address.
     * - The inner key (`token`) represents the ERC20 token address.
     * - If `token` is `address(0)`, the value represents the user's native ETH balance.
     * - The stored value (`balance`) is the total amount deposited by the user for that specific token.
     */
    mapping(address user => mapping(address token => uint256 balance)) public userTokenBalance;

    /// @notice Stores the Chainlink price feed for each token.
    /// @dev Maps a token address (ERC20 or address(0) for ETH) to its AggregatorV3Interface price feed contract.
    ///      The price feed returns the token price in USD with its feed decimals.
    mapping(address => AggregatorV3Interface) public priceFeeds;
    /*///////////////////////
    Events
    ////////////////////////*/

     /**
     * @notice Emitted when a new price feed address is set in the contract.
     * @param token is The address of the new token with newPriceFeed that is your newly registered oracle.
     */
    event NewPriceFeed(address token, address newPriceFeed);

    /**
     * @notice Emitted when a user withdraws ETH or tokens from the contract.
     * @param user The address of the user performing the withdrawal.
     * @param amount The amount of ETH or tokens withdrawn.
     */
    event Withdraw(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user deposits tokens or ETH into the contract.
     * @param user The address of the user who made the deposit.
     * @param token The address of the token deposited. 
     *        Use address(0) to indicate a deposit in native ETH.
     * @param amount The amount of tokens or ETH deposited.
     */
    event DepositToken(address indexed user, address indexed token, uint256 amount);
    /**
     * @notice Emitted when a user withdraws tokens or ETH from the contract.
     * @param user The address of the user who made the withdrawal.
     * @param token The address of the token withdrawn. 
     *        Use address(0) to indicate a withdrawal in native ETH.
     * @param amount The amount of tokens or ETH withdrawn.
     */
    event WithdrafToken(address indexed user, address indexed token, uint256 amount);

    /*///////////////////////
    Errors
    ///////////////////////*/

    /**
     * @notice Thrown when the bank's maximum cap is exceeded by a deposit.
     * @param deposit The attempted deposit amount.
     * @param balanceBank The current total balance held by the bank.
     * @param maxCapBank The maximum allowed total balance for the bank.
     * @param user The address of the user who attempted the deposit.
     */
    error MaxCapBank(uint256 deposit, uint256 balanceBank, uint256 maxCapBank, address user);

    /**
     * @notice Thrown when the maximum withdrawal amount per transaction is exceeded.
     * @param amount The requested withdrawal amount.
     * @param withdraw The maximum allowed withdrawal amount per transaction.
     * @param user The address of the user attempting the withdrawal.
     */
    error MaxWithdrawPerTransaction(uint256 amount, uint256 withdraw, address user);

    /**
     * @notice Thrown when a withdrawal transaction fails during execution.
     * @param error The low-level error data returned by the failed call.
     */
    error WithdrawFail(bytes error);

    /**
     * @notice Thrown when the user has insufficient balance to perform a withdrawal.
     * @param amount The requested withdrawal amount.
     * @param balance The current balance available for the user.
     */
    error WithoutSufficientBalance(uint256 amount, uint256 balance);

    /***
    *@notice deploy the contract and initialize variables
    *@dev decalres immutables variables for difine the permissions
    *@param recive two uint256 parameters of variables for initialize, _maxWithdraftPerTransaction nad  _maxCapBank
    */

     /*///////////////////////
            Functions
    ///////////////////////*/
    constructor(uint256 _maxWithdraftPerTransaction, 
    uint256  _maxCapBank, 
    address _USDC, 
    address _initialOwner)
    Ownable(_initialOwner)
    { 
        MAX_WITHDRAFT_PER_TRANSACTION = _maxWithdraftPerTransaction;
        MAX_CAP_BANK = _maxCapBank;
        USDC=IERC20(_USDC);
        priceFeeds[_USDC] = AggregatorV3Interface(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19);
        priceFeeds[address(0)] = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }
    
    
     /**
     * @dev Ensures that the new deposit does not exceed the maximum allowed bank cap.
     * Reverts with {MaxCapBank} if the total balance after the deposit would exceed `MAX_CAP_BANK`.
     * @param _amount The amount of ETH or tokens being deposited.
     */
    modifier maxCapBank(uint256 _amount, address _token,uint8 _tokenDecimals) {
        if ((getContractBalance() + tokenAmountInUSD(_token, _amount, _tokenDecimals)) > MAX_CAP_BANK) {
            revert MaxCapBank(
                _amount, 
                address(this).balance, 
                MAX_CAP_BANK, 
                msg.sender
            );
        }
        _;
    }

    /**
     * @dev Ensures that the withdrawal amount does not exceed the per-transaction limit.
     * Reverts with {MaxWithdrawPerTransaction} if `amount` is greater than `MAX_WITHDRAFT_PER_TRANSACTION`.
     * @param amount The requested withdrawal amount.
     */
    modifier maxWithdraw(uint256 amount, address tokenAddress, uint8 tokenDecimals) {
        //uint8 tokenDecimals = 8;
       // if(tokenAddress == address(0)){tokenDecimals = 20;}
        if (tokenAmountInUSD (tokenAddress, amount, tokenDecimals)> MAX_WITHDRAFT_PER_TRANSACTION) {
            revert MaxWithdrawPerTransaction(
                amount, 
                MAX_WITHDRAFT_PER_TRANSACTION, 
                msg.sender
            );
        }
        _;
    }

    /**
     * @dev Ensures that the user has sufficient balance to perform a withdrawal.
     * Reverts with {WithoutSufficientBalance} if `amount` exceeds the user's available balance.
     * @param amount The requested withdrawal amount.
     */
    modifier withoutSufficientBalance(uint256 amount,address _tokenAddress) {
        uint256 balance = userTokenBalance[msg.sender][_tokenAddress];
        if (amount > balance) {
            revert WithoutSufficientBalance(amount, balance);
        }
        _;
    }

     /**
     * @notice Fallback function that accepts ETH deposits sent via a low-level call or incorrect function selector.
     * @dev 
     * - Applies the {maxCapBank} modifier to ensure the bank cap is not exceeded.
     * - Increments the user's ETH balance under `userTokenBalance[msg.sender][address(0)]`.
     * - Calls the internal `_registerOfDeposit()` function for accounting or tracking.
     * - Emits a {Deposit} event upon success.
     */
    fallback() external payable maxCapBank(msg.value, address(0),20) { 
        unchecked {
            userTokenBalance[msg.sender][address(0)] += msg.value;
        }
        _registerOfDeposit();
        emit DepositToken(msg.sender, address(0), msg.value);
    }

    /**
     * @notice Receives plain ETH transfers sent directly to the contract.
     * @dev 
     * - Triggered automatically when no data is sent in the transaction.
     * - Applies the {maxCapBank} modifier to prevent exceeding the bank cap.
     * - Updates the user's ETH balance and registers the deposit.
     * - Emits a {Deposit} event.
     */
    receive() external payable maxCapBank(msg.value, address(0),20) {
        unchecked {
            userTokenBalance[msg.sender][address(0)] += msg.value;
        }
        _registerOfDeposit();
        emit DepositToken(msg.sender, address(0), msg.value);
    }

    /**
     * @notice Allows users to deposit ETH manually via a direct function call.
     * @dev 
     * - Applies the {maxCapBank} modifier to prevent exceeding the bank cap.
     * - Uses `unchecked` for gas efficiency since overflow is impossible in this context.
     * - Updates the user's balance and registers the deposit.
     * - Emits a {Deposit} event.
     */
    function deposit() external payable maxCapBank(msg.value, address(0),20) {
        unchecked {
            userTokenBalance[msg.sender][address(0)] += msg.value;
        }
        _registerOfDeposit();
        emit DepositToken(msg.sender, address(0), msg.value);
    }
    
   /**
     * @notice Deposits a specific amount of ERC20 tokens into the contract.
     * @dev Uses `transferFrom`, so the user must have approved this contract beforehand.
     * @param _tokenAmount The number of tokens to deposit.
     * @param _tokenAddress The ERC20 token contract address.
     */
    function depositToken(uint256 _tokenAmount, address _tokenAddress, uint8 decimals) external 
    maxCapBank( _tokenAmount,_tokenAddress, decimals){
        userTokenBalance[msg.sender][_tokenAddress] += _tokenAmount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);
        emit DepositToken(msg.sender, _tokenAddress, _tokenAmount);
    }
    /**
     * @notice Withdraws a specific amount of tokens or ETH from the contract.
     * @dev If `_tokenAddress` is address(0), it sends ETH instead of ERC20 tokens.
     * @param _tokenAmount The number of tokens or ETH to withdraw.
     * @param _tokenAddress The ERC20 token address or address(0) for ETH.
     * @return data Additional return data (e.g. call result for ETH transfer).
     */
    function withdrafToken(uint256 _tokenAmount, address _tokenAddress, uint8 tokenDecimals)  external 
    withoutSufficientBalance(_tokenAmount, _tokenAddress) maxWithdraw(_tokenAmount, _tokenAddress, tokenDecimals)
             returns(bytes memory data ) {
        if(_tokenAddress == address(0)){
            unchecked{
                userTokenBalance[msg.sender][_tokenAddress] -= _tokenAmount;
                }
            emit WithdrafToken(msg.sender, _tokenAddress, _tokenAmount);
            data= _withdraft(msg.sender, _tokenAmount);
            _registerOfWithdraft();
            return data;
            }
        else{
            uint256 _userTokenBalance = userTokenBalance[msg.sender][_tokenAddress];
            if(_userTokenBalance < _tokenAmount){
                revert WithoutSufficientBalance(_userTokenBalance,_tokenAmount);}
            unchecked {
                userTokenBalance[msg.sender][_tokenAddress] -= _tokenAmount;
            }

            IERC20(_tokenAddress).transfer(msg.sender, _tokenAmount);
            emit WithdrafToken(msg.sender, _tokenAddress, _tokenAmount);
            return data;
        }
    }
    /**
     * @notice Sets a new Chainlink price feed for a specific token.
     * @dev Only the contract owner can call this function.
     *      Each token is associated with an AggregatorV3Interface contract returning its USD price.
     *      If a feed already exists for the token, it will be overwritten.
     *      Emits a {NewPriceFeed} event with the token address and the new feed address.
     * @param token The address of the ERC20 token (use address(0) for ETH).
     * @param feed The address of the Chainlink AggregatorV3Interface contract for the token.
     * 
     * Requirements:
     * - Only the `owner` can call this function.
     * - `feed` must be a valid address (not address(0)).
     * 
     * Emits a {NewPriceFeed} event.
     */
    function setPriceFeed(address token, address feed) external onlyOwner {
       priceFeeds[token] = AggregatorV3Interface(feed);
       emit NewPriceFeed(token, address(priceFeeds[token]));
    }
    
     /**
    * @notice Sends ETH to a specified user.
    * @dev 
    * - Uses `call` to transfer `amount` of ETH to `user`.
    * - Reverts with {WithdrawFail} if the transfer fails.
    * - Returns the raw call data for potential use by the caller.
    * - Private function; meant to be called internally only.
    * @param user The address to receive the ETH.
    * @param amount The amount of ETH to send (in wei).
    * @return data The raw bytes returned from the `call`.
    */
    function _withdraft(address user, uint256 amount) private returns (bytes memory) {
        (bool success, bytes memory data)=user.call{value: amount}("");
        if(!success) revert WithdrawFail(data);
        return data;
    }
     ///@notice increases the record of total deposits
    function _registerOfDeposit() internal {
        ++totalDeposits;
    }
    ///@notice increases the record of total withdrawals
    function _registerOfWithdraft() internal{
        ++totalWithdraft;
    }
    /**
    * @notice Converts a given amount of ETH to its USD equivalent using the oracle price.
    * @dev 
    * - `_tokenAmount` is in wei.
    * - `getEthPrice()` returns the latest ETH/USD price from the oracle (with DECIMAL_ETHUSD decimals).
    * - The result is scaled to match the decimal system of your internal accounting.
    * @param _tokenAmount The amount of ETH to convert (in wei).
    * @return _priceInUSD The equivalent amount in USD, scaled according to `DECIMAL_ETHUSD`.
    */
    function convertETHinUSD (uint256 _tokenAmount) internal view returns (uint256 _priceInUSD){
        _priceInUSD = uint256((uint256(getEthPrice()) * _tokenAmount)/DECIMAL_ETHUSD);
    }

     /**
    * @notice Returns the internal token balance of the caller for a specific token.
    * @dev The balance is read from the `userTokenBalance` mapping.
    *      Use `address(0)` as `addr` to query ETH balance.
    * @param addr The address of the ERC20 token, or `address(0)` for ETH.
    * @return The internal token balance of the caller.
    */
    function getUserTokenBalance(address addr) external view returns (uint256) {
        return userTokenBalance[msg.sender][addr];

    }
   
     /**
     * @notice Retrieves the latest USD price of a given token from its Chainlink price feed.
     * @dev Reads the latest round data from the AggregatorV3Interface associated with the token.
     *      Reverts if the price is zero or negative.
     * @param token The address of the ERC20 token (or address(0) for ETH).
     * @return price The latest price of the token in USD, scaled according to the feed's decimals.
     */
    function getTokenPriceUSD(address token) internal view returns (uint256) {
        (, int256 price,,,) = priceFeeds[token].latestRoundData();
        require(price > 0, "invalid price");
        return uint256(price);
    }

    /**
     * @notice Converts a given token amount to its USD value using the Chainlink price feed.
     * @dev Calculates: `usdValue = amount * price / (10 ** tokenDecimals)`.
     *      Price is obtained from the feed associated with the token.
     *      Ensure that MAX_WITHDRAFT_PER_TRANSACTION uses the same decimal scale as the usdValue.
     * @param token The address of the ERC20 token (or address(0) for ETH).
     * @param amount The amount of tokens to convert.
     * @param tokenDecimals The number of decimals of the token (usually 18 for ETH, 6 for USDC/USDT).
     * @return usdValue The value of the token amount in USD, scaled according to the feed's decimals.
     */
    function tokenAmountInUSD(address token, uint256 amount, uint8 tokenDecimals) internal view returns (uint256) {
         uint256 price = getTokenPriceUSD(token); 
         uint256 usdValue = (amount * price) / (10 ** tokenDecimals); 
         return usdValue;
    }

   
    /**
    * @notice Returns the latest ETH price from the priceFeeds.
    * @dev 
    * - Uses the `latestRoundData` function from the `AggregatorV3Interface` interface.
    * - Only returns the price (`answer`) field; ignores other round data.
    * - The returned price typically has 8 decimals (depends on price feed).
    * @return _price The latest ETH price from the AggregatorV3Interface.
    */
    function getEthPrice () public view returns (int256 _price){
          (, int256 price, , , )  = (priceFeeds[address(0)]).latestRoundData();
        _price = price;
    }

     /**
    * @notice Returns the total balance of the contract in USD-equivalent.
    * @dev 
    * - Converts the contract's ETH balance to USD using `convertTokeninUSD`.
    * - Adds the contract's USDC balance from `userTokenBalance`.
    * @return _balance The total balance of the contract in USD-equivalent.
    */

    function getContractBalance ()  public view returns (uint256 _balance) {
        return (convertETHinUSD(address(this).balance)+USDC.balanceOf(address(this)));
        //en caso de agregar mas monedas se podria almacenar los addr de los tokens en una lista y luego ir convirtiendo y sumando los mismos
    }
}
