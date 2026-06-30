// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @notice A contract that allows deployers of Gnosis Safe wallets to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of a Safe factory and copy on this chain
    SafeProxyFactory public immutable cook;
    address public immutable cpy;

    uint256 public constant pay = 1 ether;
    address public immutable chief;
    address public immutable gem;

    address public mom; // slot 0, authorizer 주소
    address public hat; // slot 1

    error Boom();

    constructor(address _gem, address _cook, address _cpy, address _chief) {
        gem = _gem; // token 주소
        cook = SafeProxyFactory(_cook);
        cpy = _cpy; // safe 구현체 주소
        chief = _chief; //deployer 주소
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     */
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom; // authorizer 주소
    }

    /**
     * @notice Allows the caller to deploy a new Safe account and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment
     */
    function drop(address aim, bytes memory wat, uint256 num) external returns (bool) {
        if (mom != address(0) && !can(msg.sender, aim)) {
            return false;
        }

        // safe 지갑 배포
        // createProxyWithNonce(safe singleton주소, initializer, nonce))
        if (address(cook.createProxyWithNonce(cpy, wat, num)) != aim) {
            return false;
        }

        if (IERC20(gem).balanceOf(address(this)) >= pay) {
            IERC20(gem).transfer(msg.sender, pay);
        }
        return true;
    }

    function can(address u, address a) public view returns (bool y) {
        assembly {
            let m := sload(0) // slot 0 로드, authorizer 주소
            if iszero(extcodesize(m)) { stop() }
            let p := mload(0x40) // free memory pointer 로드
            mstore(0x40, add(p, 0x44)) // 사용할 calldata 크기만큼 free memory pointer 증가 -> 구역 표시, 쓰기전에 예약
            // p부터 calldata 작성
            mstore(p, shl(0xe0, 0x4538c4eb)) // 앞쪽 4바이트에 넣기 위해 28바이트 왼쪽 시프트
            mstore(add(p, 0x04), u) // p + 4 위치에 u 작성 [p + 0x04]
            mstore(add(p, 0x24), a) // p + 36 위치에 a 작성[p + 0x24]
            // 가스, 호출 대상, 만들어둔 calldata, calldata 크기, 리턴 데이터 위치, 리턴 데이터 최대 크기
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { stop() }
            y := mload(p) // p 위치에 있는 값 로드 => 위의 staticcall 리턴값
        }
    }
}
