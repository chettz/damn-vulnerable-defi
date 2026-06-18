// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IHasTrustedForwarder {
    function trustedForwarder() external view returns (address);
}

contract BasicForwarder is EIP712 {
    struct Request {
        address from;
        address target;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data; 
        uint256 deadline;
    }

    error InvalidSigner();
    error InvalidNonce();
    error OldRequest();
    error InvalidTarget();
    error InvalidValue();

    bytes32 private constant _REQUEST_TYPEHASH = keccak256(
        "Request(address from,address target,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 deadline)"
    );

    mapping(address => uint256) public nonces;

    /**
     * @notice Check request and revert when not valid. A valid request must:
     * - Include the expected value
     * - Not be expired
     * - Include the expected nonce
     * - Target a contract that accepts this forwarder
     * - Be signed by the original sender (`from` field)
     */
    function _checkRequest(Request calldata request, bytes calldata signature) private view {
        if (request.value != msg.value) revert InvalidValue();
        if (block.timestamp > request.deadline) revert OldRequest();
        if (nonces[request.from] != request.nonce) revert InvalidNonce();

        if (IHasTrustedForwarder(request.target).trustedForwarder() != address(this)) revert InvalidTarget();

        // signature를 통해서 from 주소 검증
        // _hashTypedData()는 어떤 함수?
        // =>
        // 도메인 정보까지 묶은 실제로 서명하는 최종 digest를 계산하는 함수
        /*
            digest = _hashTypedData(getDataHash(request))   // 32 bytes

            오프체인 (지갑):
            (r, s, v) = sign(digest, userPrivateKey)
            signature = r (32) ‖ s (32) ‖ v (1)   // 총 65 bytes

            온체인 (forwarder):
            signer = ECDSA.recover(digest, signature)
        */
        // ECDSA.recover()는 서명에 대응하는 EOA 주소 반환
        address signer = ECDSA.recover(_hashTypedData(getDataHash(request)), signature);
        if (signer != request.from) revert InvalidSigner();
    }

    function execute(Request calldata request, bytes calldata signature) public payable returns (bool success) {
        _checkRequest(request, signature);

        nonces[request.from]++;

        uint256 gasLeft;
        uint256 value = request.value; // in wei
        address target = request.target;
        // payload[0:32] = length
        // payload[32: ] = data + from
        bytes memory payload = abi.encodePacked(request.data, request.from);
        uint256 forwardGas = request.gas;
        // target의 함수 호출
        assembly {
            success := call(forwardGas, target, value, add(payload, 0x20), mload(payload), 0, 0) // don't copy returndata
            gasLeft := gas()
        }

        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "BasicForwarder";
        version = "1";
    }

    function getDataHash(Request memory request) public pure returns (bytes32) {
        // _REQUEST_TYPEHASH와 실제 값을 규칙대로
        return keccak256(
            abi.encode(
                _REQUEST_TYPEHASH,
                request.from,
                request.target,
                request.value,
                request.gas,
                request.nonce,
                keccak256(request.data),
                request.deadline
            )
        );
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function getRequestTypehash() external pure returns (bytes32) {
        return _REQUEST_TYPEHASH;
    }
}
