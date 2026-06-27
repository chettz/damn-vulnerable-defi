### 문제 상황

현재 NFT 6개가 개당 15ETH에 판매 중인데, 판매 중인 NFT모두를 탈취할 수 있다는 취약점이 존재한다.

NFT를 회수에서 돌려주면 45ETH를 받을 수 있다.

현재 uniswapV2Pair가 15,000 DVT : 9,000 WETH 비율로 존재한다.

0.1ETH를 가지고 마켓플레이스의 취약점을 이용해 NFT를 모두 회수하여 돌려주고 45ETH를 얻는 것이 목표이다.

문제를 통과하기 위해서는 recoveryMangerOwner에게 NFT 6개에 대한 소유권이 있어야 하고, 마켓 플레이스에 자금과 NFT가 남아있으면 안되고, 공격자의 잔고에는 45ETH가 있어야 한다.

### 문제 해결

마켓플레이스의 buyMany()를 통해 여러 개의 NFT를 한번에 구매할 수 있는데, 호출 시 지불한 이더(msg.value)가 NFT 1개 가격보다 크기만 하면 3개든 4개든 구매 가능하다. 즉 NFT 1개 가격으로 여러 개 살 수 있다.

또한 NFT 구매 시 구매자에게 NFT를 전송후, NFT 소유주에게 NFT 가격만큼 이더를 전송한다. NFT를 구매자에게 전송 후         `payable(_token.ownerOf(tokenId)).sendValue(priceToPay)`를 호출하면 이미 NFT의 소유주가 seller에서 구매자로 바뀌었기 때문에 이더가 구매자에게 전송된다.

1. flashswap으로 15ETH를 빌린다.
2. buyMany{value : 15 ether}(tokendIds);로 NFT 6개를 구매한다.
3. 이때 공격자는 마켓플레이스 취약점으로인해 90ether 수신
4. 15ether + fee repay
5. RecoveryManager에게 NFT 전송하여 bounty 수령




