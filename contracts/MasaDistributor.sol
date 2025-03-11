// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MasaDistributor is Ownable, ReentrancyGuard {
    error MasaDistributor__CannotBeZeroAddress();
    error MasaDistributor__ClaimAmountCannotBeZero();
    error MasaDistributor__ClaimCountThresholdExceeded();
    error MasaDistributor__InvalidProof(address user, uint256 amount, bytes32[] proof);
    error MasaDistributor__NoTokensToWithdraw(address token);

    IERC20 private immutable i_masa;
    bytes32 private s_root;
    mapping(address user => uint256 times) private claimCount;

    uint256 private s_claimCountThreshold;

    event Claimed(address indexed user, uint256 amount);
    event ClaimCountThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event TokenWithdrawn(address indexed token, address indexed receiver, uint256 amount);

    constructor(address _masa, bytes32 _root) Ownable(msg.sender) {
        if (_masa == address(0)) {
            revert MasaDistributor__CannotBeZeroAddress();
        }
        i_masa = IERC20(_masa);
        s_root = _root;
        s_claimCountThreshold = 0;
    }

    /**
     * @notice Allows eligible users to claim MASA tokens based on the merkle proof verification
     * @dev This function enables users to claim 25% of their total token allocation in each batch.
     *      The claim count threshold will be increased when a new claim batch is opened, allowing
     *      users to claim additional portions of their allocation in subsequent batches.
     *      Each successful claim increments the user's claim count by 1.
     * @param _amount The amount of MASA tokens to claim (25% of total allocation)
     * @param _proof The merkle proof that verifies the user's eligibility and claim amount
     * @custom:throws MasaDistributor__ClaimCountThresholdExceeded if user has already claimed the maximum allowed times
     * @custom:throws MasaDistributor__InvalidProof if the provided merkle proof is invalid
     * @custom:emits Claimed when tokens are successfully claimed by a user
     */
    function claim(uint256 _amount, bytes32[] calldata _proof) external nonReentrant {
        _revertIfClaimCountThresholdExceeded(msg.sender);
        _revertIfClaimWithZeroAmount(_amount);
        bool isCanClaim = checkCanClaim(msg.sender, _amount, _proof);
        if (!isCanClaim) {
            revert MasaDistributor__InvalidProof(msg.sender, _amount, _proof);
        }

        claimCount[msg.sender] += 1;
        emit Claimed(msg.sender, _amount);

        i_masa.transfer(msg.sender, _amount);
    }

    /**
     * @notice Updates the claim count threshold that controls the number of claims users can make
     * @dev This function is used to manage the phased token distribution, where users can claim
     *      25% of their total token allocation in each phase. By incrementing the threshold monthly,
     *      the owner enables users to claim their next 25% portion. For example, setting it to:
     *      - 1: Allows users to claim first 25% of their tokens
     *      - 2: Opens second batch, allowing users to claim up to 50% of their allocation
     *      - 3: Opens third batch, allowing users to claim up to 75% of their allocation
     *      - 4: Opens final batch, allowing users to claim 100% of their allocation
     * @param _newThreshold The new maximum number of claims allowed per user
     * @custom:emits ClaimCountThresholdUpdated when the threshold is successfully updated
     */
    function updateClaimCountThreshold(uint256 _newThreshold) external onlyOwner {
        emit ClaimCountThresholdUpdated(s_claimCountThreshold, _newThreshold);
        s_claimCountThreshold = _newThreshold;
    }

    function updateMerkleRoot(bytes32 _newRoot) external onlyOwner {
        emit MerkleRootUpdated(s_root, _newRoot);
        s_root = _newRoot;
    }

    /**
     * @notice Withdraws all tokens of a specified ERC20 contract from this contract to the owner
     * @dev Only callable by the contract owner
     * @param _token Address of the ERC20 token contract to withdraw
     * @custom:throws MasaDistributor__NoTokensToWithdraw if the contract has no balance of the specified token
     * @custom:emits TokenWithdrawn when tokens are successfully withdrawn
     */
    function withdrawTokens(address _token) external onlyOwner {
        IERC20 tokenToWithdraw = IERC20(_token);
        uint256 balance = tokenToWithdraw.balanceOf(address(this));

        if (balance == 0) {
            revert MasaDistributor__NoTokensToWithdraw(_token);
        }

        emit TokenWithdrawn(_token, address(owner()), balance);

        tokenToWithdraw.transfer(address(owner()), balance);
    }

    /**
     * @notice Verifies if a user can claim a specified amount of tokens
     * @dev Checks if user has exceeded claim threshold, validates amount is not zero,
     *      and verifies the user and amount against the Merkle tree
     * @param _user Address of the user attempting to claim tokens
     * @param _amount Amount of tokens to claim
     * @param _proof Merkle proof to validate the claim
     * @return bool True if the claim is valid, false otherwise
     */
    function checkCanClaim(address _user, uint256 _amount, bytes32[] calldata _proof) public view returns (bool) {
        _revertIfClaimCountThresholdExceeded(_user);
        _revertIfClaimWithZeroAmount(_amount);

        bytes32 leaf = keccak256(abi.encode(_user, _amount));
        return MerkleProof.verify(_proof, s_root, leaf);
    }

    function _revertIfClaimCountThresholdExceeded(address _user) internal view {
        if (claimCount[_user] >= s_claimCountThreshold) {
            revert MasaDistributor__ClaimCountThresholdExceeded();
        }
    }

    function _revertIfClaimWithZeroAmount(uint256 _amount) internal pure {
        if (_amount == 0) {
            revert MasaDistributor__ClaimAmountCannotBeZero();
        }
    }

    function getClaimCount(address user) external view returns (uint256) {
        return claimCount[user];
    }

    function getMasaToken() external view returns (address) {
        return address(i_masa);
    }

    function getRoot() external view returns (bytes32) {
        return s_root;
    }

    function getClaimCountThreshold() external view returns (uint256) {
        return s_claimCountThreshold;
    }
}
