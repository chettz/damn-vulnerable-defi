ERC-3156 : 플래시 론을 제공하는 대출자(Lender)와 차용자(Borrower) 계약이 구현해야 할 규격 제시

A. IERC3156FlashLender - 대출 서비스 제공자가 구현해야 하는 인터페이스
- maxFlashLoan(token) : 현재 대출 가능한 최대 금액
- flashFee(token, amount) : 수수료 계산
- flashLoan(receiver, token, amout, data) : 플래시 론을 실행하는 핵심 함수
  - receiver(borrower)에게 토큰 전송
  - borrower의 onFlashLoan함수를 호출하여 차용자(borrower)에게 실행 제어권을 넘김
  - borrower가 작업을 완료하고 상환을 위해 토큰+수수료를 보냈는지 확인

B. IERC3156FlashBorrower - 플래시론을 사용하려는 계약이 구현해야 하는 인터페이스
- onFlashLoan(initiator, token, amount, fee, data) : Lender계약이 플래시론 실행 직후 호출하는 콜백 함수
  - borrower는 빌린 금액을 활용해서 차익거래, 청산 등의 로직을 단일 트랜잭션 내에서 실행
  - 로직 완료 후 빌린 금액(amount)과 수수료(fee)를 합한 금액을 lender에게 다시 전송, 검증을 위한 해시값 리턴

C. 플래시 론의 작동 방식
    1. Borrower가 Lender의 flashLoan 함수를 호출

    2. 대출자는 토큰과 함께 차용자의 onFlashLoan 함수를 호출

    3. 차용자는 onFlashLoan 함수 내에서 빌린 자금으로 모든 작업을 수행

    4. 차용자는 작업 완료 후, 대출자에게 원금과 수수료를 상환

    5. 대출자는 onFlashLoan 호출이 성공적으로 반환되고 상환이 완료되었는지 확인

    6. 이 모든 과정(1~5단계)이 단 하나의 이더리움 트랜잭션으로 처리됨



---------------------------------------------------

UnstoppableVault가 FlashLender에 해당

UnstoppableMonitor가 FlashBorrower에 해당

Unstoppable에서의 flashloan 동작 단계

    1. vault.flashloan 호출
    2. flashloan 안에서 빌리려는 토큰 양이 0인지, 기초 자산과 일치하는지, 금고 회계 불변식 검사
    3. FlashLender인 Vault가 토큰을 FlashBorrower인 Monitor에게 전송
    4. Vault가 Monitor의 onFlashLoan 호출

