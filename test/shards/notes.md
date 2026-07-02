### 문제 상황

Shards NFT 마켓은 허가없는 스마트 컨트랙트로 NFT를 원하는 가격에 팔 수 있다.

NFT를 쪼개서 shard단위로 팔 수 있고, 구매자들은 ERC1155형태로 소유할 수 있다.

마켓은 온전한 NFT 1개가 다 팔려야 판매자에게 대금을 지불한다.

또한 판매자에게 수수료 1%를 청구하고 이는 DVT staking 시스템과 연동된 온체인 vault에 저장된다.

seller가 현재 NFT를 100만 USDC가격에 판매 등록을 했고, 수수료로 판매가격의 1%인 10,000USDC 상당의 750DVT를 marketplace가 가져간 상태이다.

공격자는 DVT없이 marketplace의 자금을 가져와야 한다.

### 문제 해결

marketplace의 fill()호출을 통해 shard를 구매하고, shard가 전부 팔리면 fill안에서 _closeOffer를 호출하여 판매자에게 대금을 지불하고 구매자들에게 shard를 발급한다.

marketplace에서 정의한 취소 기간 상수와 실제 cancel에서 확인하는 취소기간이 서로 다르다.
상수 값에서는 구매 후 1-3일 이내에 취소할 수 있음을 의도했지만, cancel에서는 구매 후 1일 이내에만 취소할 수 있도록 조건식을 세웠다. 즉 구매 후 즉시 취소도 가능하다.

shard 구매시 fiil()에서 구매자로부터 가져가는 DVT양 계산식과 구매 취소 cancel() 호출시 구매자에게 환불해주는 계산식이 서로 다르다.

- fill()에서의 DVT양 계산식
```solidity
paymentToken.transferFrom(
            msg.sender, address(this), want.mulDivDown(_toDVT(offer.price, _currentRate), offer.totalShards)
        );
```
위 식은 shard를 want개 구매 시 구매자가 지불해야 할 DVT를 계산한다.
mulDivDown(a, b, c)는 a * b / c(내림)이다. 
_toDVT(offer.price, _currentRate) => USDC 가격을 DVT로 환산(NFT 전체 가격 75,000DVT)
지불해야할 DVT = want x (75,000DVT) / 10,000,000shard
shard를 1e18개 구매하는 경우 => 1e18 x 75e21 / 10,000,000e18
                        = 7.5e15 wei
                        = 0.0075 DVT
논리적 shard 1개는 1e18인데, 인자로 받는 want는 uint256이므로 1wei 단위까지 shard를 살 수 있다.

want가 1일 경우 다음과 같다.
```
1 × 75e21 ÷ 10_000_000e18 = 0.00075...  →  mulDivDown = 0
                                        →  mulDivUp = 1 
```

즉 shard 구매시 want로 1을 넘겨주면 DVT 지불 없이 shard를 구매할 수 있다.

DVT 지불없이 구매가능한 최대 shards 개수는 다음과 같다.
```
want < totalShards / totalPriceDVT
     = 10,000,000e18 / 75,000e18
     ≈ 133.33...
```

- cancel()에서의 DVT양 계산식
```solidity
paymentToken.transfer(buyer, purchase.shards.mulDivUp(purchase.rate, 1e6));
```
환불해주는 DVT양은 다음과 같다.
```
shards * rate / 1e6  = shards * 75e15 * 1e6 = shards * 75e9
```
지불할때의 DVT 양 계산식과 같은 공식이 아니다.

shard 1wei 개 구매시 지불했던 DVT는 0이지만 같은 shard 개수에 대해 환불하면 다음과 같다.
```
(1 * 75e15 / 1e6) = 75e9 wei
```
shard 1wei개 구매시 0DVT를 지불했는데 환불 시 75e9 wei를 받게된다.


### 공격 방법

DVT 지불 없이 shard 구매 및 환불 요청을 통해 문제에서 요구하는 initialTokensinmarketplace * 1e16 / 100e18 이상 즉 0.075 DVT 이상을 환불받아야 한다.

한번에 0.075DVT 이상을 환불 받기 위해 필요한 최소 shard 개수는?
```
shards * 75e15 / 1e6  > 75e15
shards > 1e6
```
그러나 shard 1e6개는 DVT 지불없이 구매 가능한 shard 개수인 133개를 초과하므로, 먼저 소량의 shard 구매 및 취소 요청을 통해 DVT를 확보해야한다.

또한, shard 1e6개 구매시 소모되는 DVT개수는 다음과 같다.
```
1,000,000 * 75e21 / 10,000,000e18 = 750wei
```


shard 1wei개를 구매 및 취소 요청하여 75e9wei DVT를 확보한다. shard 1e6개 구매 시 필요한 충분한 DVT를 확보했다.

넉넉하게 shard 2e6개 구매 및 취소 요청하여 0.15DV를 확보할 수 있다.






#### mulDivUp vs mulDivDown

둘다 x * y / denominator를 계산하지만 나머지가 있을 때 반올림 방향이 다르다.

solidity 정수 나눗셈은 소수를 버리므로 mulDivDown은 일반 나눗셈과 같고, mulDivUp은 나머지가 1이라도 있으면 +1을 한다.


ex1) - 나누어 떨어지는 경우
```
mulDivDown(10, 6, 3) = ⌊60 ÷ 3⌋ = 20
mulDivUp(10, 6, 3)   = ⌈60 ÷ 3⌉ = 20
```
ex2) - 나머지가 있는 경우
```
10 × 3 ÷ 4 = 30 ÷ 4 = 7.5

mulDivDown(10, 3, 4) = ⌊7.5⌋ = 7
mulDivUp(10, 3, 4)   = ⌈7.5⌉ = 8
```
ex3) - 아주 작은 값의 경우
```
1 × 1 ÷ 3 = 0.333...

mulDivDown(1, 1, 3) = 0
mulDivUp(1, 1, 3)   = 1
```


### 완화 방안 및 시사점 by AI

**완화 방안**

1. **결제·환불 공식 통일** — `fill()`과 `cancel()`에서 동일한 공식과 동일한 반올림 방향을 사용한다. 가장 안전한 방법은 구매 시 실제 지불액(`paidAmount`)을 `Purchase`에 저장하고, 취소 시 그 값을 그대로 환불하는 것이다.
2. **반올림 방향 일관성** — 사용자에게 불리한 방향으로 반올림한다. 수취(결제)는 `mulDivUp`, 지급(환불)은 `mulDivDown`을 적용해 0 DVT 구매가 불가능하게 한다.
3. **최소 구매 단위 강제** — `want`에 최소 shard 단위(예: `1e18`)를 요구해 wei 단위 구매로 인한 정밀도 손실을 차단한다.
4. **취소 기간 로직 수정** — `TIME_BEFORE_CANCEL`과 `CANCEL_PERIOD_LENGTH` 조건식을 의도(구매 후 1~3일)에 맞게 수정한다. 상수와 실제 검증 로직이 일치하는지 단위 테스트로 확인한다.
5. **불변식(invariant) 검증** — `Σ 환불액 ≤ Σ 결제액`, `feesInBalance ≤ 잔액` 등 회계 불변식을 fuzz/property 테스트로 지속 검증한다.

**시사점**

- 정수 연산에서 `mulDivDown`/`mulDivUp`의 반올림 방향이 다르면, 아주 작은 금액(1 wei)에서도 프로토콜이 손해를 볼 수 있다. DeFi에서 흔한 취약점 패턴이다.
- 결제 시점과 환불 시점에 서로 다른 공식을 쓰면, 가격 환산·shard 분할 과정에서 누적 오차가 자금 유출로 이어진다.
- 주석·상수로 표현한 비즈니스 규칙과 실제 `require`/`if` 조건이 어긋나면, 의도치 않은 즉시 취소 같은 허점이 생긴다.
- 소액·경계값(0, 1 wei, 나머지 발생 분수) 테스트는 금융 로직에서 필수이며, 실제 지불·환불 대칭성을 저장값 기반으로 검증하는 것이 가장 확실하다.