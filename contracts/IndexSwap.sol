pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IBalancerLib.sol";

import "./interfaces/IPriceOracle.sol";
import "./interfaces/IWETH.sol";

contract TokenBase is ERC20, ERC20Burnable, Ownable, AccessControl {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}
}

contract IndexSwap is TokenBase, BMath {
    IUniswapV2Router02 public pancakeSwapRouter;

    // IERC20 public token;
    using SafeMath for uint256;

    uint256 public indexPrice;

    address private vault;

    /**
     * @dev Token record data structure
     * @param lastDenormUpdate timestamp of last denorm change
     * @param denorm denormalized weight
     * @param index index of address in tokens array
     */
    struct Record {
        uint40 lastDenormUpdate;
        uint96 denorm;
        uint8 index;
    }
    // Array of underlying tokens in the pool.
    address[] internal _tokens;

    // Internal records of the pool's underlying tokens
    mapping(address => Record) internal _records;

    // Total denormalized weight of the pool.
    uint256 internal constant TOTAL_WEIGHT = 10_000;

    // Total denormalized weight of the pool.
    uint256 internal MAX_INVESTMENTAMOUNT;

    bytes32 public constant ASSET_MANAGER_ROLE =
        keccak256("ASSET_MANAGER_ROLE");

    IPriceOracle oracle;

    address outAssest;

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault,
        uint256 _maxInvestmentAmount
    ) TokenBase(_name, _symbol) {
        pancakeSwapRouter = IUniswapV2Router02(_pancakeSwapAddress);
        oracle = IPriceOracle(_oracle);
        vault = _vault;
        outAssest = _outAssest; //As now we are tacking busd
        MAX_INVESTMENTAMOUNT = _maxInvestmentAmount;

        // OpenZeppelin Access Control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ASSET_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(ASSET_MANAGER_ROLE, msg.sender);
    }

    /** @dev Emitted when public trades are enabled. */
    event LOG_PUBLIC_SWAP_ENABLED();

    /**
     * @dev Sets up the initial assets for the pool.
     * @param tokens Underlying tokens to initialize the pool with
     * @param denorms Initial denormalized weights for the tokens
     */
    function initialize(address[] calldata tokens, uint96[] calldata denorms)
        external
        onlyOwner
    {
        require(_tokens.length == 0, "INITIALIZED");
        uint256 len = tokens.length;
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            _records[tokens[i]] = Record({
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denorms[i],
                index: uint8(i)
            });
            _tokens.push(tokens[i]);

            totalWeight = badd(totalWeight, denorms[i]);
        }
        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");

        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    /**
     * @notice The function calculates the amount of index tokens the user can buy/mint with the invested amount.
     * @param _amount The invested amount after swapping ETH into portfolio tokens converted to BNB to avoid slippage errors
     * @param sumPrice The total value in the vault converted to BNB
     * @return Returns the amount of index tokens to be minted.
     */
    function _mintShareAmount(uint256 _amount, uint256 sumPrice)
        internal
        view
        returns (uint256)
    {
        uint256 indexTokenSupply = totalSupply();

        return _amount.mul(indexTokenSupply).div(sumPrice);
    }

    // START LIBRARY FUNCTION CONTRACT

    /**
     * @notice The function calculates the balance of each token in the vault and converts them to BNB and the sum of those values which represents the total vault value in BNB
     * @return tokenXBalance A list of the value of each token in the portfolio in BNB
     * @return vaultValue The total vault value in BNB
     */
    function getTokenAndVaultBalance()
        public
        view
        returns (uint256[] memory tokenXBalance, uint256 vaultValue)
    {
        uint256 len = _tokens.length;
        uint256[] memory tokenBalanceInBNB = new uint256[](len);
        uint256 vaultBalance = 0;

        if (totalSupply() > 0) {
            for (uint256 i = 0; i < len; i++) {
                uint256 tokenBalance = IERC20(_tokens[i]).balanceOf(vault);
                uint256 tokenBalanceBNB;

                tokenBalanceBNB = _getTokenAmountInBNB(
                    _tokens[i],
                    tokenBalance
                );

                tokenBalanceInBNB[i] = tokenBalanceBNB;
                vaultBalance = vaultBalance.add(tokenBalanceBNB);

                require(vaultBalance > 0, "sum price is not greater than 0");
            }
            return (tokenBalanceInBNB, vaultBalance);
        } else {
            return (new uint256[](0), 0);
        }
    }

    /**
     * @notice The function calculates the amount in BNB to swap from BNB to each token
     * @dev The amount for each token has to be calculated to ensure the ratio (weight in the portfolio) stays constant
     * @param tokenAmount The amount a user invests into the portfolio
     * @param tokenBalanceInBNB The balanace of each token in the portfolio converted to BNB
     * @param vaultBalance The total vault value of all tokens converted to BNB
     * @return A list of amounts that are being swapped into the portfolio tokens
     */
    function calculateSwapAmounts(
        uint256 tokenAmount,
        uint256[] memory tokenBalanceInBNB,
        uint256 vaultBalance
    ) internal view returns (uint256[] memory) {
        uint256[] memory amount = new uint256[](_tokens.length);
        if (totalSupply() > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                amount[i] = tokenBalanceInBNB[i].mul(tokenAmount).div(
                    vaultBalance
                );
            }
        }

        return amount;
    }

    // END LIBRARY FUNCTION CONTRACT

    /**
     * @notice The function swaps BNB into the portfolio tokens after a user makes an investment
     * @dev The output of the swap is converted into BNB to get the actual amount after slippage to calculate the index token amount to mint
     * @dev (tokenBalanceInBNB, vaultBalance) has to be calculated before swapping for the _mintShareAmount function because during the 
            swap the amount will change but the index token balance is still the same (before minting)
     */
    function investInFund() public payable {
        uint256 tokenAmount = msg.value;
        require(
            tokenAmount <= MAX_INVESTMENTAMOUNT,
            "Amount exceeds maximum investment amount!"
        );
        uint256 investedAmountAfterSlippage = 0;
        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;
        uint256[] memory amount = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        amount = calculateSwapAmounts(
            tokenAmount,
            tokenBalanceInBNB,
            vaultBalance
        );

        investedAmountAfterSlippage = _swapETHToTokens(tokenAmount, amount);
        require(
            investedAmountAfterSlippage <= tokenAmount,
            "amount after slippage can't be greater than before"
        );
        if (totalSupply() > 0) {
            tokenAmount = _mintShareAmount(
                investedAmountAfterSlippage,
                vaultBalance
            );
        } else {
            tokenAmount = investedAmountAfterSlippage;
        }

        _mint(msg.sender, tokenAmount);

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    /**
     * @notice The function swaps the amount of portfolio tokens represented by the amount of index token back to BNB and returns it to the user
               and burns the amount of index token being withdrawn
     * @param tokenAmount The index token amount the user wants to withdraw from the fund
     */
    function withdrawFund(uint256 tokenAmount) public {
        require(
            tokenAmount <= balanceOf(msg.sender),
            "caller is not holding given token amount"
        );

        uint256 totalSupplyIndex = totalSupply();

        _burn(msg.sender, tokenAmount);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];

            uint256 tokenBalance = IERC20(t).balanceOf(vault);
            uint256 amount = tokenBalance.mul(tokenAmount).div(
                totalSupplyIndex
            );

            if (t == getETH()) {
                _pullFromVault(t, amount, msg.sender);
            } else {
                _pullFromVault(t, amount, address(this));
                _swapTokenToETH(t, amount, msg.sender);
            }
        }
    }

    // START REBALANCING CONTRACT

    /**
     * @notice The function sells the excessive token amount of each token considering the new weights
     * @param _oldWeights The current token allocation in the portfolio
     * @param _newWeights The new token allocation the portfolio should be rebalanced to
     * @return sumWeightsToSwap Returns the weight of tokens that have to be swapped to rebalance the portfolio (buy)
     */
    function sellTokens(
        uint256[] memory _oldWeights,
        uint256[] memory _newWeights
    ) internal returns (uint256 sumWeightsToSwap) {
        // sell - swap to BNB
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_newWeights[i] < _oldWeights[i]) {
                address t = _tokens[i];
                uint256 tokenBalance = IERC20(t).balanceOf(vault);
                uint256 weightDiff = _oldWeights[i].sub(_newWeights[i]);
                uint256 swapAmount = tokenBalance.mul(weightDiff).div(
                    _oldWeights[i]
                );

                _pullFromVault(t, swapAmount, address(this));
                _swapTokenToETH(t, swapAmount, address(this));
            } else if (_newWeights[i] > _oldWeights[i]) {
                uint256 diff = _newWeights[i].sub(_oldWeights[i]);
                sumWeightsToSwap = sumWeightsToSwap.add(diff);
            }
        }
    }

    /**
     * @notice The function swaps the sold BNB into tokens that haven't reached the new weight
     * @param _oldWeights The current token allocation in the portfolio
     * @param _newWeights The new token allocation the portfolio should be rebalanced to
     */
    function buyTokens(
        uint256[] memory _oldWeights,
        uint256[] memory _newWeights,
        uint256 sumWeightsToSwap
    ) internal {
        uint256 totalBNBAmount = address(this).balance;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            if (_newWeights[i] > _oldWeights[i]) {
                uint256 weightToSwap = _newWeights[i].sub(_oldWeights[i]);
                require(weightToSwap > 0, "weight not greater than 0");
                require(sumWeightsToSwap > 0, "div by 0, sumweight");
                uint256 swapAmount = totalBNBAmount.mul(weightToSwap).div(
                    sumWeightsToSwap
                );

                _swapETHToToken(t, swapAmount, vault);
            }
        }
    }

    /**
     * @notice The function rebalances the token weights in the portfolio
     */
    function rebalance() public {
        require(
            hasRole(ASSET_MANAGER_ROLE, msg.sender),
            "Caller is not an Asset Manager"
        );
        require(totalSupply() > 0);

        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;

        uint256[] memory newWeights = new uint256[](len);
        uint256[] memory oldWeights = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        for (uint256 i = 0; i < _tokens.length; i++) {
            oldWeights[i] = tokenBalanceInBNB[i].mul(TOTAL_WEIGHT).div(
                vaultBalance
            );
            newWeights[i] = uint256(_records[_tokens[i]].denorm);
        }

        uint256 sumWeightsToSwap = sellTokens(oldWeights, newWeights);
        buyTokens(oldWeights, newWeights, sumWeightsToSwap);
    }

    /**
     * @notice The function updates the token weights and rebalances the portfolio to the new weights
     * @param denorms The new token weights of the portfolio
     */
    function updateWeights(uint96[] calldata denorms) public {
        require(
            hasRole(ASSET_MANAGER_ROLE, msg.sender),
            "Caller is not an Asset Manager"
        );
        require(denorms.length == _tokens.length, "Lengths don't match");

        updateRecords(_tokens, denorms);
        rebalance();
    }

    /**
     * @notice The function evaluates new denorms after updating the token list
     * @param tokens The new portfolio tokens
     * @param denorms The new token weights for the updated token list
     * @return A list of updated denorms for the new token list
     */
    function evaluateNewDenorms(
        address[] memory tokens,
        uint96[] memory denorms
    ) internal view returns (uint256[] memory) {
        uint256[] memory newDenorms = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                if (_tokens[i] == tokens[j]) {
                    newDenorms[i] = denorms[j];
                    break;
                }
            }
        }
        return newDenorms;
    }

    /**
     * @notice The function updates the record struct including the denorm information
     * @param tokens The updated token list of the portfolio
     * @param denorms The new weights for for the portfolio
     */
    function updateRecords(address[] memory tokens, uint96[] memory denorms)
        internal
    {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            _records[tokens[i]] = Record({
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denorms[i],
                index: uint8(i)
            });
            totalWeight = badd(totalWeight, denorms[i]);
        }

        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");
    }

    /**
     * @notice The function rebalances the portfolio to the updated tokens with the updated weights
     * @param tokens The updated token list of the portfolio
     * @param denorms The new weights for for the portfolio
     */
    function updateTokens(address[] memory tokens, uint96[] memory denorms)
        public
    {
        require(
            hasRole(ASSET_MANAGER_ROLE, msg.sender),
            "Caller is not an Asset Manager"
        );
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            totalWeight = badd(totalWeight, denorms[i]);
        }
        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");

        uint256[] memory newDenorms = evaluateNewDenorms(tokens, denorms);

        if (totalSupply() > 0) {
            // sell - swap to BNB
            for (uint256 i = 0; i < _tokens.length; i++) {
                address t = _tokens[i];
                // token removed
                if (newDenorms[i] == 0) {
                    uint256 tokenBalance = IERC20(t).balanceOf(vault);

                    _pullFromVault(t, tokenBalance, address(this));
                    _swapTokenToETH(t, tokenBalance, address(this));

                    delete _records[t];
                }
            }
        }
        updateRecords(tokens, denorms);

        _tokens = tokens;

        rebalance();
    }

    // END REBALANCING CONTRACT

    /**
     * @notice The function sets the path (ETH, token) for a token
     * @return Path for (ETH, token)
     */
    function getPathForETH(address crypto)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = getETH();
        path[1] = crypto;

        return path;
    }

    /**
     * @notice The function sets the path (token, ETH) for a token
     * @return Path for (token, ETH)
     */
    function getPathForToken(address token)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = getETH();

        return path;
    }

    /**
     * @return Returns the address of the base token (WETH, WBNB, ...)
     */
    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    /**
     * @notice
     */
    function _pullFromVault(
        address t,
        uint256 amount,
        address to
    ) internal {
        TransferHelper.safeTransferFrom(t, vault, to, amount);
    }

    /**
     * @notice The function swaps ETH to a specific token
     * @param t The token being swapped to the specific token
     * @param swapAmount The amount being swapped
     * @param to The address where the token is being send to after swapping
     * @return swapResult The outcome amount of the specific token afer swapping
     */
    function _swapETHToToken(
        address t,
        uint256 swapAmount,
        address to
    ) internal returns (uint256 swapResult) {
        if (t == getETH()) {
            IWETH(t).deposit{value: swapAmount}();
            swapResult = swapAmount;
            if (to != address(this)) {
                IWETH(t).transfer(to, swapAmount);
            }
        } else {
            swapResult = pancakeSwapRouter.swapExactETHForTokens{
                value: swapAmount
            }(
                0,
                getPathForETH(t),
                to,
                block.timestamp // using 'now' for convenience, for mainnet pass deadline from frontend!
            )[1];
        }
    }

    /**
     * @notice The function swaps ETH to the portfolio tokens
     * @param tokenAmount The amount being used to calculate the amount to swap for the first investment
     * @param amount A list of amounts specifying the amount of ETH to be swapped to each token in the portfolio
     * @return investedAmountAfterSlippage
     */
    function _swapETHToTokens(uint256 tokenAmount, uint256[] memory amount)
        internal
        returns (uint256 investedAmountAfterSlippage)
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            Record memory record = _records[t];
            uint256 swapAmount;
            if (totalSupply() == 0) {
                swapAmount = tokenAmount.mul(record.denorm).div(TOTAL_WEIGHT);
            } else {
                swapAmount = amount[i];
            }

            require(address(this).balance >= swapAmount, "not enough bnb");

            uint256 swapResult = _swapETHToToken(t, swapAmount, vault);

            investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                _getTokenAmountInBNB(t, swapResult)
            );
        }
    }

    /**
     * @notice The function swaps a specific token to ETH
     * @param t The token being swapped to ETH
     * @param swapAmount The amount being swapped
     * @param to The address where ETH is being send to after swapping
     * @return swapResult The outcome amount in ETH afer swapping
     */
    function _swapTokenToETH(
        address t,
        uint256 swapAmount,
        address to
    ) internal returns (uint256 swapResult) {
        if (t == getETH()) {
            IWETH(t).withdraw(swapAmount);
            if (to != address(this)) {
                IWETH(t).transfer(to, swapAmount);
            }
            swapResult = swapAmount;
        } else {
            TransferHelper.safeApprove(
                t,
                address(pancakeSwapRouter),
                swapAmount
            );
            swapResult = pancakeSwapRouter.swapExactTokensForETH(
                swapAmount,
                0,
                getPathForToken(t),
                to,
                block.timestamp
            )[1];
        }
    }

    /**
     * @notice The function converts the given token amount into BNB
     * @param t The base token being converted to BNNB
     * @param amount The amount to convert to BNB
     * @return amountInBNB The converted BNB amount
     */
    function _getTokenAmountInBNB(address t, uint256 amount)
        internal
        view
        returns (uint256 amountInBNB)
    {
        if (t == getETH()) {
            return amount;
        }

        uint256 decimal = oracle.getDecimal(t);
        uint256 tokenPrice = oracle.getTokenPrice(t, outAssest);
        amountInBNB = tokenPrice.mul(amount).div(10**decimal);
    }

    // important to receive ETH
    receive() external payable {}
}
