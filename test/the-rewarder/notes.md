문제 상황

- 컨트랙트가 현재 DVT와 WETH를 보상으로 분배 중

- 보상을 수령하기 위해서는 beneficiaries에 있음을 증명해야 함

- distributor로 부터 최대한 많은 자금을 가져와서 recovery로 전송해야 함

- player 몫 - dvt : 0.011dvt, wETH : 0.012wETH

보상을 수령하고 싶으면 distribution 목록에 등록되어있는 (주소, 수량)이어야 하고, msg.sender와 amount가 (주소, 수량)과 일치해야 수령 가능

다른 사람의 보상을 수령하려면 해당 beneficiary의 private key가 필요한데 어떻게 공격자가 보상을 수령할 수 있는지? => 불가능능

player의 주소도 distribution목록에 존재 => player가 정상적인 보상을 수령하는 과정에서 취약점으로 인해 추가적인 보상을 획득할 수 있는 가능성?
=>
dvt 보상 수령에서 weth 보상 수령으로 넘어갈때, dvt 보상 기록을 flush 하게되는데 이때 _setClaimed로 넘겨지는 wordPosition이 weth의 batchNumber에 의존하게되는데, 이때 dvt와 weth가 모두 batchnumber가 0이면 상관없지만, weth의 batch number가 256인경우 dvt의 bitmap의 wordPosition이 밀릴 수 있음
=> 이 방법은 batch를 새로 생성해야 하는데 기존 보상이 분배가 완료되지 않았기 때문에 불가능

보상 토큰 전송이 다 이루어지고 난 후에 bitsmap이 기록됨, 이렇게 되면 같은 토큰, 같은 배치에 대해 중복으로 토큰 전송 후 마지막에 만 보상 수령 기록이 저장됨 => 즉 자신의 몫을 중복으로 여러번 수령할 수 있게됨

Mitigation

- 토큰 전송 바로 직전에 _setClaimed를 호출하여 먼저 bitsmap으로 해당 배치 토큰에 대한 수령 기록을 먼저 저장 후 토큰을 전송해야 한다.



