### 문제 상황

defi 웹서비스를 조사하다가 16진수 형태의 수상한 서버 응답을 받은 상황이다.

관련된 온체인 거래소에서는 DVNFT를 말도 안되는 가격인 999ETH에 팔고 있다.

해당 가격은 3명의 reporter로 구성된 온체인 오라클로부터 가져온다.

0.1ETH를 가지고 거래소의 모든 자금을 가져와야 한다.

### 수상한 서버 응답?

정황상 16진수로 된 서버 응답은 오라클 reporter중 2명의 개인키가 유출된 것 같다.

이를 확인하기 위해 16진수를 ascii로 바꿔보면 각각 다음과 같다.

MHg3ZDE1YmJhMjZjNTIzNjgzYmZjM2RjN2NkYzVkMWI4YTI3NDQ0NDc1OTdjZjRkYTE3MDVjZjZjOTkzMDYzNzQ0

MHg2OGJkMDIwYWQxODZiNjQ3YTY5MWM2YTVjMGMxNTI5ZjIxZWNkMDlkY2M0NTI0MTQwMmFjNjBiYTM3N2M0MTU5

MHg는 Base64 디코딩 시 0x로 개인키라고 추측할 수 있다.
개인키 = 0x + 64자리 hex
주소 = 0x + 40자리 hex

위의 문자열을 base64 디코딩 하면 각각 다음과 같다.

0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744

0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159

전형적인 private key 형태이다. 각 private key로 부터 주소를 얻어보면 다음과 같다.

cast wallet address --private-key 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744
=> 0x188Ea627E3531Db590e6f1D71ED83628d1933088

cast wallet address --private-key 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159
=> 0xA417D473c40a4d42BAd35f147c21eEa7973539D8

문제에서 말한 3명의 오라클 reporter 중에서 2명의 주소와 일치하는 것을 확인할 수 있다.

### 오라클 작동 방식? reporter들이 가격을 어떻게 제공하고 최종 가격이 어떻게 산출되는가?

현재 reporter 계정은 2 ether씩 가지고 있다. 

오라클 컨트랙트 설명을 읽어보면 오라클의 가격은 truested sources(reporters)들이 제공한 가격의 중간값이다.

앞선 과정에서 2개의 유출된 reporter private key를 가지고 있으므로 NFT 구매 시 0.1ether로 구매가능하게 오라클 가격을 낮춰서 구매할 수 있다.

이후에 NFT를 판매할 때는 다시 가격을 999ETH로 올려서 최종적으로 거래소에서 모든 자금을 가져올 수 있다.


### 공격 과정
1. 유출된 각 개인키를 가지고 각각 postPrice("DVNFT", 0)을 호출하여 median price를 0으로 맞춤

2. 공격자가 nft를 1wei로 구매, 이때 거래소에서는 1wei 다시 환불(거래소 잔액 : 0)

3. 다시 유출된 개인키를 가지고 nft 가격을 999ether로 조정

4. player가 nft를 판매 이때 median price는 위 3번과정에 의해 다시 999ether로 상승

5. 받은 이더 recovery로 전송

이렇게 하면 문제 해결 확인 조건인 median price를 999ether로 유지하면서 거래소 잔고도 0으로 유지한채 통과할 수 있다.
