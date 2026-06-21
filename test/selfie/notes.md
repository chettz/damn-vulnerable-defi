문제상황

- 거버넌스 메카니즘이 추가된 lending pool이 flash loan을 제공하고 있고, pool안에는 1.5million DVT 토큰이 있다.

- 공격자는 주어진 토큰 없이 pool안의 자금을 모두 회수해야 한다.

회수 방안

selfiepool의 emergencyExit함수를 보면 pool에 있는 토큰 전체를 receiver로 전송한다. 하지만 해당 함수를 호출하려면 msg.sender가 governance여야 한다.

그렇다면 governance에서 외부 컨트랙트(selfiepool)로 함수를 호출하는 로직이 있는가?
=> executeAction이라는 target의 함수를 호출하는 함수 존재

executeAction의 동작은 어떻게 되는가?
=>
mapping 키로 actionId를 인자로 받은 후, GovernanceAction을 찾아 미리 queue된 target의 함수를 호출한다.

실행할 수 있는 조건은 다음과 같다. 해당 actionId가 존재해야하고, 아직 실행되지 않았어야 하며, 제안 후 2일이 지나야한다.

selfiepool의 emergencyExit(recovery)를 호출하는 Action을 생성 후 vm.roll로 시간을 경과 시킨 후 executionAction(actionId)를 호출하면 되지 않을까?
=>
Action은 어떻게 생성?
=>
1. governance의 queueAction 호출
2. 조건 검사
    - msg.sender가 충분한 투표권을 가지고 있는지 검사 => 전체 투표권 2,000,000개 중 절반이상의 투표권을 가지고 있어야 함, 현재 공격자는 투표권이 없음
    - 인자로 넣는 target 주소가 governance와 일치하면 revert => selfiepool  의 함수를 호출할 것이므로 문제 x
    - 대상 주소에 코드가 존재하는지 검사 => 호출하려는 컨트랙트가 governance 컨트랙트이므로 문제 x

Action 생성 시 문제가 되는 부분은 호출자의 투표권이 부족하다는 점인데 어떻게 1,000,000개 이상의 투표권을 확보할 수 있는가?
=>
flash loan으로 현재 pool에 존재하는 1,500,000개의 DVV 토큰을 빌린 후, onflashLoan안에서 action 생성 후 빌린 토큰 반납. 현재 selfiepool에서 flash loan 수행 시 추가적인 수수료를 가져가지 않으므로 호출자의 잔고가 0 이어도 flash loan을 통한 공격이 가능하다.

공격 시나리오

1. attack 컨트랙트에서 pool.flashLoan(attack, DVV, TOKENS_IN_POOL, bytes("")) 호출
2. pool -> attack.onFlashLoan호출
3. onFlashLoan안에서 공격자 스스로에게 투표권 부여
4. queueAction(governance, 0, abi.encodeCallSelfiePool.emergencyExit, (recovery)); 호출
5. vm.roll
6. attack 컨트랙트에서 executionAction(1) 호출
