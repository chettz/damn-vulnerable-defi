// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;
import {Test} from "forge-std/Test.sol";
contract NonceTest is Test {
    address player = makeAddr("player");
    function test_prank_calls_only() public {
        vm.startPrank(player);
        address(0x1).call("");
        address(0x2).call("");
        vm.stopPrank();
        emit log_uint(vm.getNonce(player));
    }
}
