### 문제 상황

권한이 있는 금고에 DVT 1백만개가 들어있고, 정기적으로 일부 자금을 인출할 수 있고 비상시에는 모든 자금을 인출할 수 있다.

컨트랙트에는 권한 쳬계가 있어서 등록된 계정만 특정 동작을 수행할 수 있다.

금고 안의 자금을 모두 빼와야 한다.


### 문제 해결

문제 setup 과정에서 설정되는 player와 deployer의 permission?
    player는 `Vault::withdraw`를 deployer는 `Vault::sweepFunds`를 execute를 통해 실행할 수 있는 권한 부여
    player는 modifier onlyThis 때문에 vault의 withdraw를 직접 호출하지 못하고 execute를 통해서만 withdraw를 호출할 수 있다.

금고에서 자금을 인출하는 정상적인 경로는 어떻게 되는가?
=> 
vault의 execute()를 호출하여 withdraw()를 호출할 수 있는데, 이 경우 15일마다 자금을 인출할 수 있으므로 공격이 불가하다.
=>
execute에서 permission 검증 시에 인자로 넘긴 actionData에서 앞 4바이트 selector를 뽑고, msg.sender 그리고 인자로 넘김 target을 가지고 permissions에 등록되어 있는지 확인한다.
=> 
이때 selector를 확인하는 과정에서 actionData에서 직접 읽어오는 것이 아니라 트랜잭션 calldata에서 고정 offset 위치 100으로 읽어온다.

[0:4]     execute selector
[4:36]    target (address, 32바이트 패딩) - vault 주소
[36:68]   actionData offset 포인터 0x40(64)
[68:100]  actionData length
[100:]    actionData 실제 데이터  ← calldataOffset = 4 + 32*3 = 100
            ├─ [100:104]  내부 함수 selector (4바이트)
            └─ [104:]     나머지 인자들


만약에 actionData offset 포인터 위치를 기존 0x40에서 공격자가 실제로 수행할 data 위치로 바꿀 경우 sweepFunds()를 호출할 수 있다.

즉 트랜잭션 calldata에서 offset 100에는 검증 통과용으로 withdraw.selector를 배치하고 실제 actionData의 시작위치를 가리키는 actionData offset 포인터를 sweepFunds.selector가 있는 곳을 가리킬 수 있다.
=>
공격용 전체 calldata를 구성해보면 다음과 같다.
[0:4]       execute selector -> 0x1cff79cd
[4:36]      target  -> vault
[36:68]     offset = 0x64  (100)
[68:100]    패딩 (32바이트)
[100:104]   withdraw selector  ← 권한 체크
[104:136]   actionData length -> 4 + 32 + 32 = 68
[136:]      sweepFunds calldata  ← 실제 실행


### 완화 방안

문제에서는 권한 체크와 실행에 서로 다른 바이트 값을 읽어오고 있어서 문제가 발생한다.

트랜잭션 전체 calldata에서 assembly로 raw calldata를 읽는 것이 아닌, 인자로 받은 이미 디코딩 된 actionData에서 직접 슬라이스 하여 selector를 확인해야 한다.
```solidity
bytes4 selector = bytes4(actionData[:4]); 
```


#### Dynamic ABI 타입?

Dynamic ABI 타입은 calldata 크기가 **호출마다 달라지는** 타입이다.

**Static vs Dynamic**

| 구분 | 예시 | calldata 크기 |
|------|------|---------------|
| Static | `uint256`, `address`, `bool`, `bytes32` | 항상 32바이트 |
| Dynamic | `bytes`, `string`, `T[]`, 동적 배열 | 가변 |

`execute(address target, bytes actionData)`에서 `address`는 static, `bytes`는 dynamic이다.

**Dynamic 타입 인코딩 구조**

함수 인자의 고정 영역에는 실제 데이터 대신 **포인터(offset)** 만 둔다.

```
[고정 영역]
  target          (32바이트)
  offset → 0x40   (32바이트)  "뒤쪽 어디에 실제 데이터가 있는지"

[동적 영역]  ← offset이 가리키는 곳
  length          (32바이트)  "데이터가 몇 바이트인지"
  data            (length바이트, 32바이트 단위로 패딩)
```

정상 `execute(vault, sweepFundsCalldata)` 호출 시:

```
[4:36]    target
[36:68]   offset = 0x40
[68:100]  length = 68
[100:]    sweepFunds calldata
```

**왜 dynamic인가?**
=> `bytes` / `string` / 배열은 길이가 호출마다 다르기 때문에 고정 영역에 다 넣을 수 없다.
=> 그래서 뒤쪽에 데이터를 붙이고, 앞에는 "어디에 있는지(offset)"만 둔다.
=> 디코더는 offset → length → data 순으로 읽는다.

**이 문제와의 연결**
=> 공격은 offset 포인터를 `0x40` → `0x64`로 바꿔 Solidity가 읽는 동적 영역을 옮긴 것이다.
=> 권한 체크(취약 코드): 고정 바이트 100 → `withdraw`
=> Solidity 디코더: offset이 가리키는 곳(136) → `sweepFunds`
=> dynamic 타입 = offset + length + data 구조

**assembly로 offset을 따라 읽는 방법** (권장은 `bytes4(actionData[:4])`이지만 참고용)

```solidity
assembly {
    let relOffset := calldataload(36)              // bytes 인자의 offset 포인터 (byte 36)
    let actionDataPtr := add(4, add(relOffset, 32)) // 4 + offset + length(32) 건너뜀
    selector := calldataload(actionDataPtr)         // 상위 4바이트 = selector
}
```
