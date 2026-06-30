### 문제 상황

WalletDeployer를 통해 safe 지갑을 배포하면 1 DVT를 보상으로 주는 컨트랙트가 있다.

업그레이드 가능한 권한 메커니즘과 연동되어 있어서 특정 배포자(ward)가 특정 배포에 대해서만 보상을 받을 수 있다.

팀은 2,000만 DVT를 `0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496`에게 보냈고, 해당 Safe 지갑 주소에 본인만 서명하는 safe가 배포될 예정이었는데 배포에 사용할 nonce를 잃어버렸다.

현재 시스템에 취약점이 있고, user의 privatkey를 가지고 있으며 2,000만 DVT를 user에게 돌려주어야 한다.

1. 2,000만 DVT는 이미 0xCe07... (USER_DEPOSIT_ADDRESS)로 전송됨
2. 해당 주소는 user EOA를 owner로 하는 1-of-1 Safe가 배포될 예정이었던 CREATE2 주소
3. Safe는 아직 배포되지 않음 -> 그 주소에 코드 없음, 토큰만 있음 -> 토큰에 접근 불가
4. 팀이 Safe 지갑 배포에 쓸 nonce(saltNonce)를 잃어버림
5. 그래서 Safe 지갑을 토큰을 보낸 그 주소에 다시 배포할 수 없고, user도 토큰에 접근 불가

walletDeployer에 있는 1DVT를 ward로, `0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496`에 있는 2,000만 DVT를 user 전송해야 한다.

### 문제 해결

Safe Singleton Factory - Safe, SafeProxyFactory 배포
CreateX - AuthorizerFactory, WalletDeplpyer 배포

잃어버린 nonce값 없이 `0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496`과 주소가 일치하도록 safe 지갑을 생성할 수 있는가?

WalletDeployer에 있는 1DVT를 어떻게 ward에게 전송할 수 있을까?
=>
정상적인 수령 절차는 어떻게 되는가?
=>
ward가 `WalletDeployer::drop`호출하여 USER_DEPOSIT_ADDRESS와 같은 주소의 safe 지갑을 생성하면 1DVT 획득
=> ward의 경우 AuthorizerUpgradable의 wards[ward][USER_DEPOSIT_ADDRESS]=1로 authorizer 프록시 배포시 초기화를 통해 등록되어있는 상태
=> 
msg.sender 즉 호출자가 ward가 아닌 이상 1DVT를 drop() 호출 보상을 획득하지 못함
=> 
wards에 wards[player][USER_DEPOSIT_ADDRESS]=1로 기록할 수 있는 방법이 있는지?
=>
AuthorizerUpgradable(구현체)의 초기화 함수 init은 needsInit(slot 0) 상태 변수로 needsInit 값이 0과 달라야 초기화할 수 있다. 최초 needsInit의 값은 1로 init함수를 한번 호출하면 값을 0으로 지정하여 재초기화를 막는다.
그런데 해당 구현체의 프록시 컨트랙트인 TransparentProxy의 slot 0은 upgrader를 저장하는 상태변수로 authorizer 배포시 전달한 upgrader 주소를 저장하고 있다. 이때 프록시와 구현체의 저장소 layout이 일치하지 않는다. 로직 컨트랙트에서는 slot0이 needsInit의 역할을 하고, 프록시 컨트랙트에서는 slot0이 upgrader의 역할을 하는 storage collision이 발생한다.

이때 Authorizer 배포 흐름을 따라가 보면 다음과 같다.

`AuthorizerFactory::deployWithProxy`에서 다음과 같이 프록시로 배포한다.
```solidity
authorizer = address(
            new TransparentProxy( // proxy
                address(new AuthorizerUpgradeable()), // implementation
                abi.encodeCall(AuthorizerUpgradeable.init, (wards, aims)) // init data
            )
        );
        assert(AuthorizerUpgradeable(authorizer).needsInit() == 0); // invariant
        TransparentProxy(payable(authorizer)).setUpgrader(upgrader);
```

이때 초기화 함수인 `AuthorizerUpgradeable::init`도 호출한다. 이때 초기화가 끝나면 slot0(needsInit)의 값은 0이된다.
하지만 이후 `TransparentProxy::setUpgrader`를 호출하면 slot0(upgrader)의 값이 0이 아닌 upgrader로 바뀐다.

slot0의 값이 0이 아니므로 `AuthorizerUpgradeable::init`를 한번 더 호출하여 wards[plyaer][USER_DEPOSIT_ADDRESS]를 등록할 수 있다.
