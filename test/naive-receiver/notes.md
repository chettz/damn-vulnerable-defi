1. 정상적인 forwarder 경로
player -> forwarder -> pool.withdraw인 경우 msg.data의 끝 20바이트가 request.from(=player)이므로, pool에 존재하는 player의 잔고를 출금한다.

2. multicall를 통해 withdraw를 호출하는 경우
player -> forwarder -> pool.multicall -> pool.delegatecall(withdraw)의 경우 msg.data 끝 20바이트가 withdraw의 receiver(=deployer)인자가 되어 deployer의 잔고를 출금할 수 있다. deployer의 모든 잔액 출금 이후 recovery 컨트랙트로 자금 전송

3. deployer가 배포한 FlashLoanReceiver에 있는 10WETH 자금도 recovery 컨트랙트로 전송해야한다. flashloan 고정 수수료는 1WETH이므로 multicall로 10번 호출하여 FlashLoanReceiver에 있는 모든 WETH를 pool에 수수료로 가게끔 할 수 있다. 

4. pool의 잔액을 모두 recovery로 보내서 0으로 만들어야 하므로, multicall의 순서는 3번 이후 2번이 와야한다.