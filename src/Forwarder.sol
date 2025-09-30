// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {SignatureCheckerLib} from "@solady/src/utils/SignatureCheckerLib.sol";
import {ProtocolManager} from "src/ProtocolManager.sol";

/**
 * Upgradable forwarder with injected ProtocolManager contract
 */
contract Forwarder is Initializable, UUPSUpgradeable, ERC2771ForwarderUpgradeable {
  struct State {
    ProtocolManager manager;
  }

  error DeprecatedMethod(string reason);

  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger.forwarder")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x51362966e92df5c04c0f76086a8cd5e148faf622e58eb20b42b402e453aac800;

  function _getStorage() internal pure returns (State storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := STORAGE_LOCATION
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address manager) public initializer {
    __UUPSUpgradeable_init();
    __ERC2771Forwarder_init("ZeroLedgerForwarder");
    __forwarder_init_unchained(manager);
  }

  function upgradeCallBack() external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal view override {
    require(
      _getStorage().manager.isImplementationApproved(address(this), newImplementation),
      "Implementation is not approved"
    );
  }

  function __forwarder_init_unchained(address manager) internal {
    _getStorage().manager = ProtocolManager(manager);
  }

  function verify(ForwardRequestData calldata) public pure override returns (bool) {
    revert DeprecatedMethod("Method does not support ERC6492 signature verification, use execution simulation instead");
  }

  /**
   * @dev Validates and executes a signed request returning the request call `success` value.
   * note: Using this function doesn't check that all the `msg.value` was sent, potentially
   * leaving value stuck in the contract.
   */
  function _execute(ForwardRequestData calldata request, bool requireValidRequest)
    internal
    override
    returns (bool success)
  {
    (bool isTrustedForwarder, bool active, bool signerMatch) = _ERC6492Validate(request);

    // Need to explicitly specify if a revert is required since non-reverting is default for
    // batches and reversion is opt-in since it could be useful in some scenarios
    if (requireValidRequest) {
      if (!isTrustedForwarder) {
        revert ERC2771UntrustfulTarget(request.to, address(this));
      }

      if (!active) {
        revert ERC2771ForwarderExpiredRequest(request.deadline);
      }

      if (!signerMatch) {
        revert ERC2771ForwarderInvalidSigner(request.from, request.from);
      }
    }

    // Ignore an invalid request because requireValidRequest = false
    if (isTrustedForwarder && signerMatch && active) {
      // Nonce should be used before the call to prevent reusing by reentrancy
      uint256 currentNonce = _useNonce(request.from);

      uint256 reqGas = request.gas;
      address to = request.to;
      uint256 value = request.value;
      bytes memory data = abi.encodePacked(request.data, request.from);

      uint256 gasLeft;

      assembly ("memory-safe") {
        success := call(reqGas, to, value, add(data, 0x20), mload(data), 0, 0)
        gasLeft := gas()
      }

      if (gasLeft < request.gas / 63) {
        assembly ("memory-safe") {
          invalid()
        }
      }

      emit ExecutedForwardRequest(request.from, currentNonce, success);
    }
  }

  /**
   * @dev Validates if the provided request can be executed at current block timestamp with
   * the given `request.signature` on behalf of `request.signer`.
   */
  function _ERC6492Validate(ForwardRequestData calldata request)
    internal
    returns (bool isTrustedForwarder, bool active, bool isValid)
  {
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          _FORWARD_REQUEST_TYPEHASH,
          request.from,
          request.to,
          request.value,
          request.gas,
          nonces(request.from),
          request.deadline,
          keccak256(request.data)
        )
      )
    );

    isValid = SignatureCheckerLib.isValidERC6492SignatureNow(request.from, digest, request.signature);
    isTrustedForwarder = _isTrustedByTarget(request.to);
    active = request.deadline >= block.timestamp;
  }

  function getManager() external view returns (address) {
    return address(_getStorage().manager);
  }
}
