### 문제 상황

이전 puppet 풀과 다르게 uniswapV2 library를 사용해 가격 정보를 가져오도록 오라클을 수정했다.

공격자는 20ETH와 10,000DVT를 가지고 pool의 1,000,000 DVT를 모두 탈취해야 한다.

초기 DVT/WETH의 pair의 reserve 상태는 100 DVT : 10 WETH이다.

pool에서 DVT를 빌리기 위해서는 3배 가치의 WETH를 담보로 맡겨야 한다.

### 문제 해결

토큰의 가격 정보를 _getOracleQuote()를 통해서 가져오고 있다.
    - pair의 reserve 정보를 가져온 후
    - uniswapV2Library의 quote를 호출해 가격 정보를 가져옴

UniswapV2Library.quote()는 어떻게 동작하는가?

    - quote는 토큰 양, 각 리저브 양을 인자로 받아서 다른 자산의 동등한 양을 반환
    - amountB = amountA * reserveB / reserveA;


puppet처럼 똑같이 대량 매도하여 pair의 reserve를 변화시켜 토큰의 가격을 극단적으로 낮추면 되는게 아닌지?
=>
10,000DVT 스왑 후 pool에서 1,000,000 DVT를 빌리기 위해 필요한 이더는 약 30개로 가지고 있는 이더 20개 + 스왑 후 받은 이더 약 10개를 전부 전송하여 1,000,000DVT를 성공적으로 빌릴 수 있다.

### 개선안

pair의 일시적인 리저브 상태를 가지고 가격을 결정하는 것이 아닌 시간에 따라 누적된 값을 반영하는 TWAP(Time Weighted Average Price) oracle을 사용해야 한다.
