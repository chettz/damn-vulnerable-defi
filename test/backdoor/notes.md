### 문제 상황
지갑을 더 안전하게 하기 위해 safe 지갑 registry를 배포했다.

팀원이 지갑을 배포하고 등록하면 10 DVT를 받는다.

현재 4명이 등록되어 있고, 레지스트리에는 40 DVT가 있다.

레지스트리의 취약점을 찾고 모든 토큰을 가져오면 된다.


### 배경 지식

#### Safe 멀티시그 지갑이란?

멀티시그 지갑이란?

일반 지갑(EOA)는 개인키 1개로 모든 걸 서명한다.

멀티시그(Multisig)지갑은 여러 주소(owners)가 통제하는 지갑이다.

ex :
    owners: Alice, Bob, Charlie (3명)
    threshold: 2
    돈을 보내려면 3명 중 2명의 서명이 필요

Safe란?

Safe(구) Gnosis Safe)는 이런 멀티시그 지갑을 위한 가장 많이 쓰이는 스마트 컨트랙트 지갑 중 하나이다.

Safe는 단순 “N명 중 M명 서명”만 하는 게 아니라, 예를 들면:

모듈(module): 특정 조건에서 자동 실행
fallback handler: ERC-1271 등 확장 기능
Guard: 트랜잭션 전후 검사

같은 기능도 갖춘 스마트 컨트랙트 지갑이다.

SafeProxyFactory?

새로운 Safe 지갑을 CREATE2로 배포하는 팩토리이다.

`createProxyWithCallback` - safe지갑을 하나 배포 후, 초기화 한 뒤, 지정한 callback 컨트랙트에 만들어졌다고 알려주는 함수

공식 Factory 경로로 Safe를 만들고, 만들자마자 레지스트리 같은 서드파티가 검증·후처리를 하게 하는 API라고 볼 수 있다.

### 문제 해결

beneficiaries에 등록된 4명의 사용자들의 safe 지갑을 player가 대신 만들 수 있다.

`createProxyWithCallback`호출로 지갑 배포 후 받게되는 10DVT 보상 로직은 이후 호출되는 콜백 함수인 레지스트리 컨트랙트의 `proxyCreated`에서 일어난다.

4명의 사용자의 safe 지갑 주소로 토큰 보상 10 DVT가 각각 전송된다. 

보상을 어떻게 탈취할 수 있을까?

최초 safe 지갑 초기화 시에 실행되는 `Safe::setup`를 보면 to와 data인자를 넘겨줄 경우 `setupModules`에서 to 컨트랙트 코드를 delegatecall로 한번 실행한다.

setup이 실행되는 순간부터 이미 생성된 safe 프록시 컨텍스트이다.

이때 delegatecall 프레임안에서 address(this)는 Safe 지갑이므로, 실행되는 코드는 to 컨트랙트의 코드, 수정되는 스토리지는 safe 지갑의 스토리지이다.
=> DVT 토큰에 대한 approve하는 공격 컨트랙트를 만들고, to 주소를 공격 컨트랙트 주소로, data를 해당 함수를 호출하는 data로 넘기면 대리 생성한 safe 지갑에 들어온 보상을 공격 컨트랙트가 transferFrom으로 가져올 수 있다.

왜 임의의 컨트랙트에 대한 delegatcall이 포함된 `setupModules`가 safe 지갑 초기화 로직에 포함되어 있는가?
=>
지갑 생성 시에 모듈, 가드 등 추가 설정을 하고 싶은 경우가 있는데, 지갑 생성 후 owner들이 모듈을 활성화하는 트랜잭션 서명을 하는 과정이 필요하다. 이를 건너뛰기 위해 setup안에 추가한 것이다.

사용자가 safe 지갑 생성 시에 to, data인자를 넣으면 owner 서명 전에 Safe 컨텍스트 안에서 임의의 코드가 한번 실행될 수 있다. owner들의 서명을 건너뛰고 모듈을 추가하기 위한 기능이지만, to/data를 검증하지 않으면 backdoor가 될 수 있다.


### 공격 방법

1. `createProxyWithCallback` 호출로 beneficiaries에 등록된 4명의 사용자 safe 지갑 대리 생성
    - 인자로 넘기는 initializer에 setup 함수 호출을 담아서 넘긴다.
    - setup 함수 호출 시 사용할 인자는 아래와 같다
    ```
    bytes memory initializer = abi.encodeCall(
    Safe.setup,
    (
        owners,                             // alice
        1,                                  // threshold
        attack contract addr,               // to (모듈 설정용, 없으면 0)
        abi.encodeCall(attack.approve),     // data
        address(0),                         // fallbackHandler
        address(0),                         // paymentToken
        0,                                  // payment
        payable(address(0))                 // paymentReceiver
    )
    );
    ```