### 문제 상황

UUPS 패턴으로 배포된 vault(proxy) 안에 10,000,000 DVT 토큰이 있다.

vault의 owner는 timelock 컨트랙트이고 15일마다 일정량의 토큰을 출금할 수 있다.

vault에는 비상 시에 모든 토큰을 뺄 수 있는 추가적인 역할이 있다.

timelock에는 Proposer가 1시간 후에 실행할 작업을 예약할 수 있다.

player는 0.1 ETH를 가진채로 시작하며 vault에 있는 모든 토큰을 탈취해야 한다.


### 문제 해결

UUPS 패턴은 구현체 업그레이드 로직이 구현체 쪽에 위치한 프록시 패턴이다. 

현재 ClimberVault가 UUPSUpgradable을 상속한 상태이다.

업그레이드는 다음과 같은 경로로 이루어진다. 

upgradeToAndCall() → _authorizeUpgrade()


vault안의 토큰을 어떻게 전부 가져갈 수 있을까?

Vault(proxy)의 토큰을 모두 빼내는 함수가 포함된 구현체로 새로 업그레이드 하면 가능하지 않을까?
=>
구현체를 업그레이드 할 수 있는가?
=> 
ClimberTimelock만 업그레이드 함수 호출 가능
=> 
ClimberTimelock 컨트랙트에 외부 컨트랙트 함수를 호출할 수 있는 함수가 있는가?
=>
schedule 함수에 의해 schedule된 작업을 실행할 수 있는 execute 함수 존재
=>
PROPOSER_ROLE이 부여된 사용자만 schedule할 수 있음
=>
현재 PROPOSER_ROLE은 proposer에게만 부여되어 있음
=> 
PROPOESER_ROLE을 ClimberTimelock이나 player에게 부여할 수 있는가?


`ClimberTimeLock::execute`에서 스케줄된 작업을 실행할 때, 스케줄된 이후로 delay(1hours)만큼 지났는지 검사하는 부분이 실제로 스케줄 작업이 이루어지고 난 후에 실행되는 문제점이 있다.

실제로 스케줄 상에 등록된 적이 없던 작업이라도 이미 실행되는 과정에서 delay 시간 조정, 역할 부여로 proposer role을 확보할 수 있다. 이후 schedule 함수를 호출할 수 있는 권한이 생기고, 마지막에 execute안에서 scehdule을 호출하여 이전에 수행했던 작업들에 대한 등록을 마치면 마지막 검증에서 통과하여 revert없이 트랜잭션을 마칠 수 있다.


### 공격 방법

`ClimberTimeLock::execute`안에서 operation을 아래와 같은 순서대로 수행
    - updateDelay(0) 호출 => 작업 스케줄링 후 즉시 실행가능하도록
    - _grantRole(PROPOSER_ROLE, 공격 컨트랙트) => PROPOSER_ROLE을 부여함으로써 schedule함수를 호출할 수 있도록 함
    - vault.upgradeToAndCall을 통해 구현체 주소를 공격 컨트랙트로 교체(timelock이 vault(proxy)의 owner이므로 구현체 교체 가능)
    - 교체한 악성 구현체에는 전체 자금을 sweep할 수 있는 함수 구현
    - 마지막으로 위에서 실행했던 작업들은 스케줄된 적이 없기 때문에 schedule 함수를 호출하여 operation 생성

 