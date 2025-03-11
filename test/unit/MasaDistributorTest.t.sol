// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {MasaDistributor} from "contracts/MasaDistributor.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MasaDistributorTest is Test {
    ERC20Mock public masaMock;
    MasaDistributor public masaDistributor;

    // Valid variable (generated from: scripts/GenerateTree.s.ts)
    bytes32 public constant ROOT = 0x0d6d5cc028d63d081ca9afd3c80e8125c47cb6aa9f08638224b8062f3111ace9;
    address public constant USER1_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant USER1_AMOUNT = 100 ether;
    bytes32[2] public USER1_PROOF = [
        bytes32(0x84badda4783debe520ea0bab75044fbb52bc5bebcdb4b2c9c27ce82298b96b3d),
        bytes32(0xffd814b7579341a1cb2f17cb5f99e28bc26e0b43294d427a4a7563fadd98f8bb)
    ];

    // Randomly generated variable
    bytes32 public constant RANDOM_ROOT = 0x0d6d5cc028d63d081ca9afd3c80e8125c47cb6aa9f08638224b8062f3111ace1;
    address public owner = makeAddr("owner");
    address public randomPerson = makeAddr("random person");

    receive() external payable {}

    function setUp() public {
        masaMock = new ERC20Mock();

        vm.prank(owner);
        masaDistributor = new MasaDistributor(address(masaMock), ROOT);
        masaMock.mint(address(masaDistributor), 1000 ether);
    }

    function test_AdminCanUpdateClaimThreshold() public {
        uint256 newThreshold = 4;

        vm.prank(owner);
        masaDistributor.updateClaimCountThreshold(newThreshold);

        uint256 claimCountThreshold = masaDistributor.getClaimCountThreshold();

        assertEq(claimCountThreshold, newThreshold);
    }

    function test_RevertIf_NonAdminUpdateClaimThreshold() public {
        uint256 newThreshold = 4;

        vm.prank(randomPerson);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(randomPerson)));
        masaDistributor.updateClaimCountThreshold(newThreshold);
    }

    function test_AdminCanUpdateMerkleRoot() public {
        bytes32 oldRoot = masaDistributor.getRoot();

        vm.prank(owner);
        masaDistributor.updateMerkleRoot(RANDOM_ROOT);

        bytes32 newRoot = masaDistributor.getRoot();

        assertNotEq(newRoot, oldRoot);
        assertEq(newRoot, RANDOM_ROOT);
    }

    function test_RevertIf_NonAdminUpdateMerkleRoot() public {
        vm.prank(randomPerson);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(randomPerson)));
        masaDistributor.updateMerkleRoot(RANDOM_ROOT);
    }

    modifier adminUpdateClaimThreshold() {
        vm.prank(owner);
        masaDistributor.updateClaimCountThreshold(1);
        _;
    }

    function test_CanClaim() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        vm.startPrank(USER1_ADDRESS);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        vm.stopPrank();

        uint256 userBalance = masaMock.balanceOf(USER1_ADDRESS);
        assertEq(userBalance, USER1_AMOUNT);
    }

    function test_CanClaimMultipleTimesWithIncreasingThreshold() public {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        // Set threshold to 1 and claim (should success)
        vm.prank(owner);
        masaDistributor.updateClaimCountThreshold(1);
        vm.prank(USER1_ADDRESS);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        uint256 userBalance = masaMock.balanceOf(USER1_ADDRESS);
        assertEq(userBalance, USER1_AMOUNT);

        // Try to claim again at threshold 1 (should fail)
        vm.prank(USER1_ADDRESS);
        vm.expectRevert(MasaDistributor.MasaDistributor__ClaimCountThresholdExceeded.selector);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);

        // Set threshold to 2 and claim (should success)
        vm.prank(owner);
        masaDistributor.updateClaimCountThreshold(2);
        vm.prank(USER1_ADDRESS);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        userBalance = masaMock.balanceOf(USER1_ADDRESS);
        assertEq(userBalance, USER1_AMOUNT * 2);

        // Try to claim again at threshold 2 (should fail)
        vm.prank(USER1_ADDRESS);
        vm.expectRevert(MasaDistributor.MasaDistributor__ClaimCountThresholdExceeded.selector);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
    }

    function test_RevertIf_ExceedClaimThreshold() public {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        vm.startPrank(USER1_ADDRESS);
        vm.expectRevert(MasaDistributor.MasaDistributor__ClaimCountThresholdExceeded.selector);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_RevertIf_ClaimWithInvalidAddress() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        vm.startPrank(randomPerson);
        vm.expectRevert(
            abi.encodeWithSelector(
                MasaDistributor.MasaDistributor__InvalidProof.selector, address(randomPerson), USER1_AMOUNT, user1Proof
            )
        );
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_RevertIf_ClaimWithInvalidAmount() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        uint256 randomAmount = 123 ether;

        vm.startPrank(USER1_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                MasaDistributor.MasaDistributor__InvalidProof.selector, USER1_ADDRESS, randomAmount, user1Proof
            )
        );
        masaDistributor.claim(randomAmount, user1Proof);
        vm.stopPrank();
    }

    function test_RevertIf_ClaimWithZeroAmount() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        vm.startPrank(USER1_ADDRESS);
        vm.expectRevert(MasaDistributor.MasaDistributor__ClaimAmountCannotBeZero.selector);
        masaDistributor.claim(0, user1Proof);
        vm.stopPrank();
    }

    function test_RevertIf_ClaimWithInvalidProof() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[0];

        vm.startPrank(USER1_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                MasaDistributor.MasaDistributor__InvalidProof.selector, USER1_ADDRESS, USER1_AMOUNT, user1Proof
            )
        );
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_AdminCanWithdrawTokens() public {
        uint256 initialContractBalance = masaMock.balanceOf(address(masaDistributor));

        vm.prank(owner);
        masaDistributor.withdrawTokens(address(masaMock));

        uint256 finalContractBalance = masaMock.balanceOf(address(masaDistributor));
        uint256 ownerBalance = masaMock.balanceOf(owner);

        assertEq(finalContractBalance, 0);
        assertEq(ownerBalance, initialContractBalance);
    }

    function test_RevertIf_NonAdminWithdrawTokens() public {
        vm.prank(randomPerson);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(randomPerson)));
        masaDistributor.withdrawTokens(address(masaMock));
    }

    function test_GetCheckCanClaim() public adminUpdateClaimThreshold {
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];

        // User not claimed yet (should be true)
        bool isCanClaim = masaDistributor.checkCanClaim(USER1_ADDRESS, USER1_AMOUNT, user1Proof);
        assertTrue(isCanClaim);

        // After user claim, claimCountThreshold will exceeded (should be false)
        vm.prank(USER1_ADDRESS);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        vm.expectRevert(MasaDistributor.MasaDistributor__ClaimCountThresholdExceeded.selector);
        isCanClaim = masaDistributor.checkCanClaim(USER1_ADDRESS, USER1_AMOUNT, user1Proof);
        assertFalse(isCanClaim);
    }

    function test_GetClaimCount() public adminUpdateClaimThreshold {
        // User not claim yet (should be 0)
        uint256 initialClaimCount = masaDistributor.getClaimCount(USER1_ADDRESS);
        assertEq(initialClaimCount, 0);

        // User claim (should be 1)
        bytes32[] memory user1Proof = new bytes32[](2);
        user1Proof[0] = USER1_PROOF[0];
        user1Proof[1] = USER1_PROOF[1];
        vm.prank(USER1_ADDRESS);
        masaDistributor.claim(USER1_AMOUNT, user1Proof);
        uint256 finalClaimCount = masaDistributor.getClaimCount(USER1_ADDRESS);
        assertEq(finalClaimCount, 1);
    }

    function test_GetTokenAddress() public view {
        address token = masaDistributor.getMasaToken();
        assertEq(token, address(masaMock));
    }

    function test_GetMerkleRoot() public view {
        bytes32 root = masaDistributor.getRoot();
        assertEq(root, ROOT);
    }

    function test_GetClaimCountThreshold() public {
        // Admin not updated it yet (should be 0)
        uint256 threshold = masaDistributor.getClaimCountThreshold();
        assertEq(threshold, 0);

        // Admin update threshold to 1
        vm.prank(owner);
        masaDistributor.updateClaimCountThreshold(1);
        threshold = masaDistributor.getClaimCountThreshold();
        assertEq(threshold, 1);
    }
}
