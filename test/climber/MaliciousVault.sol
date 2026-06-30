pragma solidity ^0.8.22;


import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MaliciousVault is UUPSUpgradeable {
    function drain(address token, address to, uint256 amount) external {
        SafeTransferLib.safeTransfer(token, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

}