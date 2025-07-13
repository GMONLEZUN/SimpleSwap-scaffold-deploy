// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 < 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
@title A simple swap contract
@author Gabriel Monlezun
@notice This contract gives you the posibility of swapping between two tokens and to add liquidity.
*/

contract SimpleSwap is ERC20 {
    uint256 public reserveA;
    uint256 public reserveB;
    address public tokenA;
    address public tokenB;

    /** 
    @param _tokenA Address of the contract of TokenA
    @param _tokenB Address of the contract of TokenB
    */ 
    constructor(address _tokenA, address _tokenB) ERC20("LiquidityToken","LT"){
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /** 
     * @notice Permits to add tokens to the pool to gain liquidity Tokens in return. 
     * @dev Adds liquidity to the AMM pool following the constant product formula (x * y = k).
     * @param _tokenA  Address of the contract of TokenA.
     * @param _tokenB  Address of the contract of TokenB.
     * @param amountADesired The desired amount of tokenA to add.
     * @param amountBDesired The desired amount of tokenB to add.
     * @param to Recipient of the liquidity tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountA Actual amount of tokenA added to the contract
     * @return amountB Actual amount of tokenB added to the contract
     * @return liquidity Amount of liquidity tokens minted and transferred to the user.
    */ 
    function addLiquidity(address _tokenA, address _tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity){
        require(deadline >= block.timestamp, "Deadline exceeded");
        require(_tokenA==tokenA && _tokenB==tokenB,"Token not found.");
        require(amountADesired > 0 && amountBDesired > 0,"Positive number of amount of tokens required.");
        // require(amountADesired >= amountAMin && amountBDesired >= amountBMin,"Positive number of amount of tokens required.");

        // If both reserves are empty, the square root method of calculation of liquidity is more fair than just add both amounts.
        // Slightly changed the original formula but the result it's always the same, to prevent the decimals and inaccuracies.
        if(reserveA == 0 && reserveB == 0){
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            uint256 ratioA = (amountADesired * totalSupply()) / reserveA;
            uint256 ratioB = (amountBDesired * totalSupply()) / reserveB;

            if(ratioA <= ratioB){
                liquidity = ratioA;
                amountA = amountADesired;
                amountB = (amountA * reserveB) / reserveA;
            } else {
                liquidity = ratioB;
                amountB = amountBDesired;
                amountA = (amountB * reserveA) / reserveB;
            }
        }

        // Check if the actual amount of both tokens it's above of what the recipient is expecting.
        require(amountA >= amountAMin, "Insufficient tokenA amount");
        require(amountB >= amountBMin, "Insufficient tokenB amount");

        // Transfer both tokens to the contract.
        IERC20(_tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(_tokenB).transferFrom(msg.sender, address(this), amountB);

        // After the tokens are transfered, modify the reserves and mint the liquidity tokens.
        reserveA += amountA;
        reserveB += amountB;
        _mint(to,liquidity);

        return (amountA, amountB, liquidity);
    }

    /** 
     * @notice Widthdraws tokens from the pool by burning the liquidity tokens. 
     * @dev Removes liquidity of the tokens from the AMM pool by burning liquitidity tokens and returning the proportional share of underlying tokens..
     * @param _tokenA  Address of the contract of TokenA.
     * @param _tokenB  Address of the contract of TokenB.
     * @param liquidity Amount of liquidity tokens to add.
     * @param amountAMin The minimum amount of tokenA to recieve. (slippage protection)
     * @param amountBMin The minimum amount of tokenB to recieve. (slippage protection)
     * @param to Recipient address for the withdrawn tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountA Actual amount of tokenA withdrawn from the pool.
     * @return amountB Actual amount of tokenB withdrawn from the pool.
    */ 
    function removeLiquidity(address _tokenA, address _tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB){
        require(deadline >= block.timestamp, "Deadline exceeded.");
        require(_tokenA==tokenA && _tokenB==tokenB,"Token not found.");
        require(liquidity > 0,"Positive number of liquidity tokens required.");
        require(liquidity <= balanceOf(msg.sender),"Insufficient funds.");

        amountA = (liquidity * reserveA) / totalSupply();
        require(amountA >= amountAMin,"TokenA amount is less than expected.");
        amountB = (liquidity * reserveB) / totalSupply();
        require(amountB >= amountBMin,"TokenB amount is less than expected.");

        reserveA -= amountA;
        reserveB -= amountB;

        _burn(msg.sender, liquidity);

        IERC20(_tokenA).transfer(to, amountA);
        IERC20(_tokenB).transfer(to, amountB);

        return (amountA, amountB);

    }
    /**
    * @notice Swaps an exact amount of input tokens for as many output tokens as possible.
    * @dev Executes a token swap using the constant product AMM formula (x * y = k).
    * @param amountIn The exact amount of input tokens to swap.
    * @param amountOutMin The minimum amount of output tokens to receive (slippage protection)
    * @param path Array of token addresses representing the swap path [tokenIn, tokenOut]
    * @param to Recipient address for the output tokens
    * @param deadline Unix timestamp after which the transaction will revert
    * @return amounts Array containing [amountIn, amountOut] - input and output token amounts
    */
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts){
        require(path.length == 2, "Invalid path length.");
        require(path[0]==tokenA && path[1]==tokenB || path[0]==tokenB && path[1]==tokenA,"Token not found.");
        require(deadline >= block.timestamp, "Deadline exceeded.");
        require(amountIn > 0, "Positive value of tokens required.");
        
        uint256 amountOut;
        uint[] memory _amounts = new uint[](2);
        if(path[0] == tokenA){
            amountOut = ((amountIn * reserveB) / (reserveA + amountIn));
            require(amountOut >= amountOutMin, "Amount out tokens is less than expected.");
            IERC20(tokenA).transferFrom(msg.sender, address(this), amountIn);
            reserveA += amountIn;
            reserveB -= amountOut;
            IERC20(tokenB).transfer(to, amountOut);
            _amounts[0]=amountIn;
            _amounts[1]=amountOut;
            return _amounts;
        } else if(path[0] == tokenB){
            amountOut = ((amountIn * reserveA) / (reserveB + amountIn));
            require(amountOut >= amountOutMin, "Amount out tokens is less than expected.");
            IERC20(tokenB).transferFrom(msg.sender, address(this), amountIn);
            reserveB += amountIn;
            reserveA -= amountOut;
            IERC20(tokenA).transfer(to, amountOut);
            _amounts[0]=amountIn;
            _amounts[1]=amountOut;
            return _amounts;
        } 
    }
    /**
    * @notice Gets the current price of tokenA in terms of tokenB.
    * @dev Returns the price ratio between the two pool tokens with 18 decimal precision.
    *      The price is calculated as (reserveB * 1e18) / reserveA, representing how many
    *      units of tokenB are needed to buy 1 unit of tokenA.
    * @param _tokenA Address of the first token (base token for price calculation)
    * @param _tokenB Address of the second token (quote token for price calculation)
    * @return price Price of tokenA denominated in tokenB, scaled by 1e18
    * 
    * @custom:precision Returns price with 18 decimal places for accuracy
    * @custom:formula price = (reserveB * 1e18) / reserveA
 */
    function getPrice(address _tokenA, address _tokenB) external view returns (uint price){
        require(_tokenA==tokenA && _tokenB==tokenB,"Token not found.");
        return (reserveB * 1e18) / reserveA; 
    }
    /**
    * @notice Calculates the amount of output tokenB for a given input amount of tokenA.
    * @dev Simulates a swap to determine output amount.
    * @param amountIn Amount of input tokens to simulate swapping
    * @param reserveIn Actual reserve of tokenA in the pool.
    * @param reserveOut Actual reserve of tokenB in the pool.
    * @return amountOut Expected amount of output tokens that would be received
    * @custom:formula amountOut = (amountIn * reserveB) / (reserveA + amountIn)
    */
    function getAmountOut(uint amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint amountOut){
        require(amountIn > 0,"Positive number of token A is required.");
        require(reserveIn > 0,"Positive of reserve of token A is required.");
        require(reserveOut > 0,"Positive of reserve of token A is required.");
  
        return ((amountIn * reserveOut) / (reserveIn + amountIn));
    }

}