pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IWETH.sol";

contract TokenBase is ERC20, ERC20Burnable, Ownable {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}
}

contract IndexSwap is TokenBase {
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

    mapping(address => uint256) admins;

    IPriceOracle oracle;

    address outAssest;

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    ) TokenBase(_name, _symbol) {
        pancakeSwapRouter = IUniswapV2Router02(_pancakeSwapAddress);
        oracle = IPriceOracle(_oracle);
        vault = _vault;
        outAssest = _outAssest; //As now we are tacking busd
        assetManagers[msg.sender] = true;
    }

    mapping(address => bool) public assetManagers;

    modifier onlyAssetManager() {
        require(assetManagers[msg.sender]);
        _;
    }

    function addAssetManager(address assetManager) public onlyAssetManager {
        require(
            assetManager != address(0),
            "Ownable: new manager is the zero address"
        );
        assetManagers[assetManager] = true;
    }

    /** @dev Emitted when public trades are enabled. */
    event LOG_PUBLIC_SWAP_ENABLED();

    /**
     * @dev Sets up the initial assets for the pool.
     *
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

            totalWeight = totalWeight.add(denorms[i]);
        }
        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");

        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function _mintShareAmount(uint256 _amount, uint256 sumPrice)
        internal
        view
        returns (uint256 price)
    {
        uint256 indexTokenSupply = totalSupply();

        return _amount.mul(indexTokenSupply).div(sumPrice);
    }

    function getTokenAndVaultBalance()
        public
        view
        returns (uint256[] memory tokenXBalance, uint256 vaultValue)
    {
        uint256 len = _tokens.length;
        uint256[] memory tokenBalanceInBNB = new uint256[](len);
        uint256 vaultBalance = 0;

        if (totalSupply() > 0) {
            /* 
                calculate the balance of all tokens in the vault (in BNB)
                has to be calculated before the swap because after the balance will change 
            */
            for (uint256 i = 0; i < len; i++) {
                uint256 tokenBalance = IERC20(_tokens[i]).balanceOf(vault);
                uint256 tokenBalanceBNB;
                if (_tokens[i] == getETH()) {
                    tokenBalanceBNB = tokenBalance;
                } else {
                    tokenBalanceBNB = _getTokenAmountInBNB(
                        _tokens[i],
                        tokenBalance
                    );
                }
                tokenBalanceInBNB[i] = tokenBalanceBNB;
                vaultBalance = vaultBalance.add(tokenBalanceBNB);

                require(vaultBalance > 0, "sum price is not greater than 0");
            }
            return (tokenBalanceInBNB, vaultBalance);
        } else {
            return (new uint256[](0), 0);
        }
    }

    function investInFund() public payable {
        uint256 tokenAmount = msg.value;
        uint256 investedAmountAfterSlippage = 0;
        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;
        uint256[] memory amount = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        //calculate the swap amount for each token to ensure that the ratio (weight in the portfolio) stays constant
        if (totalSupply() > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                amount[i] = tokenBalanceInBNB[i].mul(tokenAmount).div(
                    vaultBalance
                );
            }
        }

        // swap tokens from BNB to tokens in portfolio swapResult[1]: swapped token amount
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

            uint256 swapResult = _swapETHToTokens(t, swapAmount, vault);
            if (t == getETH()) {
                investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                    swapResult
                );
            } else {
                // take the amount actually being swapped and convert it to BNB for calculation of the index token amount to mint
                investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                    _getTokenAmountInBNB(t, swapResult)
                );
            }
        }
        require(
            investedAmountAfterSlippage <= tokenAmount,
            "amount after slippage can't be greater than before"
        );
        /*
            calculates the index token amount to mint invested amount after slippage is considered
            to make sure the index token amount represents the invested amount after slippage
        */
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
                _swapTokensToETH(t, amount, msg.sender);
            }
        }
    }

    function rebalance() public onlyAssetManager {
        uint256 sumWeightsToSwap = 0;
        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;

        uint256[] memory newWeights = new uint256[](len);
        uint256[] memory oldWeights = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        if (totalSupply() > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                oldWeights[i] = tokenBalanceInBNB[i].mul(TOTAL_WEIGHT).div(
                    vaultBalance
                );
                newWeights[i] = uint256(_records[_tokens[i]].denorm);
            }

            // sell - swap to BNB
            for (uint256 i = 0; i < _tokens.length; i++) {
                if (newWeights[i] < oldWeights[i]) {
                    address t = _tokens[i];
                    uint256 tokenBalance = IERC20(t).balanceOf(vault);
                    uint256 weightDiff = oldWeights[i].sub(newWeights[i]);
                    uint256 _swapAmount = tokenBalance.mul(weightDiff).div(
                        oldWeights[i]
                    );

                    _pullFromVault(t, _swapAmount, address(this));
                    _swapTokensToETH(t, _swapAmount, address(this));
                } else if (newWeights[i] > oldWeights[i]) {
                    uint256 diff = newWeights[i].sub(oldWeights[i]);
                    sumWeightsToSwap = sumWeightsToSwap.add(diff);
                }
            }

            // buy - swap from BNB to token
            uint256 totalBNBAmount = address(this).balance;
            for (uint256 i = 0; i < len; i++) {
                address t = _tokens[i];
                if (newWeights[i] > oldWeights[i]) {
                    uint256 weightToSwap = newWeights[i].sub(oldWeights[i]);
                    require(weightToSwap > 0, "weight not greater than 0");
                    require(sumWeightsToSwap > 0, "div by 0, sumweight");
                    uint256 swapAmount = totalBNBAmount.mul(weightToSwap).div(
                        sumWeightsToSwap
                    );

                    _swapETHToTokens(t, swapAmount, vault);
                }
            }
        }
    }

    function updateWeights(uint96[] calldata denorms) public onlyAssetManager {
        uint256 len = _tokens.length;
        require(denorms.length == len, "Lengths don't match");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            Record storage record = _records[_tokens[i]];
            record.lastDenormUpdate = uint40(block.timestamp);
            record.denorm = denorms[i];

            totalWeight = totalWeight.add(denorms[i]);
        }
        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");

        rebalance();
    }

    function updateTokens(address[] memory tokens, uint96[] memory denorms)
        public
        onlyAssetManager
    {
        uint256 len = tokens.length;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < len; i++) {
            totalWeight = totalWeight.add(denorms[i]);
        }
        require(totalWeight == TOTAL_WEIGHT, "INVALID_WEIGHTS");

        uint256[] memory newDenorms = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            for (uint256 j = 0; j < len; j++) {
                if (_tokens[i] == tokens[j]) {
                    newDenorms[i] = denorms[j];
                    break;
                }
            }
        }

        if (totalSupply() > 0) {
            // sell - swap to BNB
            for (uint256 i = 0; i < _tokens.length; i++) {
                address t = _tokens[i];
                // token removed
                if (newDenorms[i] == 0) {
                    uint256 tokenBalance = IERC20(t).balanceOf(vault);

                    _pullFromVault(t, tokenBalance, address(this));
                    _swapTokensToETH(t, tokenBalance, address(this));

                    delete _records[t];
                }
            }
        }
        for (uint256 i = 0; i < len; i++) {
            _records[tokens[i]] = Record({
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denorms[i],
                index: uint8(i)
            });
        }

        _tokens = tokens;

        rebalance();
    }

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

    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    function _pullFromVault(
        address t,
        uint256 amount,
        address to
    ) internal {
        TransferHelper.safeTransferFrom(t, vault, to, amount);
    }

    function _swapETHToTokens(
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

    function _swapTokensToETH(
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

    function _getTokenAmountInBNB(address t, uint256 amount)
        internal
        view
        returns (uint256 amountInBNB)
    {
        uint256 decimal = oracle.getDecimal(t);
        uint256 tokenPrice = oracle.getTokenPrice(t, outAssest);
        amountInBNB = tokenPrice.mul(amount).div(10**decimal);
    }

    // important to receive ETH
    receive() external payable {}
}
