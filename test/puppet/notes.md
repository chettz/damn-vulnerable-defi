### 문제 상황

DVT를 빌려주는 lending pool있는데, 빌리기 위해서는 빌리려는 양의 2배 가치의 ETH를 담보로 제공해야 한다.

lending pool에는 현재 100,000 DVT 유동성을 가진다.

또한 DVT market이 uniswap v1 거래소에 10 DVT : 10 ETH 유동성을 가진다.

공격자는 25ETH와 1,000DVT를 가지고 lending pool의 모든 토큰을 가져와야 한다.

### 문제 해결
빌리려는 양의 2배 가치의 ETH를 담보로 제공해야 함

deposit 해야하는 eth갯수를 calculateDepositRequired가 계산하는데, 토큰의 가격 정보를 uniswapv1 pair의 reserve가 아닌 balance를 통해 계산한다.

pair에 토큰을 강제로 기부함으로써 오라클 가격을 조작할 수 있다.

현재 pair는 10 ETH와 10 DVT를 가지고 있음

공격자는 100,000 DVT를 빌려야 하므로 기존에는 200,000ETH를 보내야 빌릴 수 있다.

공격자가 1,000DVT를 pair에 강제 기부하면 pair 상태는 1010 DVT : 10 ETH이고 오라클이 계산한 토큰의 가격은 약 0.0099이다

이때 보내야 하는 ETH의 양은 990ETH인데 공격자가 가진 25ETH로는 수행하지 못한다.

강제 기부가 아닌 1,000DVT를 모두 pair에 스왑 요청하면 약 9.9ETH를 받게되고 이때 pair의 상태는 대략 0.1ETH : 1007 DVT이고 토큰의 가격은 0.0000993이고 100,000DVT를 빌리는 데 필요한 ETH는 약 10개이다.