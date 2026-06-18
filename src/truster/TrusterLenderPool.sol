// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        // 대출 전 잔액 저장
        uint256 balanceBefore = token.balanceOf(address(this));

        // borrower에게 토큰 전송
        token.transfer(borrower, amount);
        // 외부 컨트랙트 함수 호출 => 어떻게 활용할 수 있을까?
        // 공격자가 임의로 작성한 컨트랙트 함수 호출 가능
        // 
        target.functionCall(data);


        // 자금이 줄어들면 revert => 어떻게 pool에서 토큰을 탈취할 수 있는지?
        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}
