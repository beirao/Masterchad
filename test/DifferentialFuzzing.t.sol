// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Masterchef} from "../src/Masterchef.sol";
import {Masterchad} from "../src/Masterchad.sol";
import {MockERC20} from "../src/utils/MockERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DifferentialFuzzingTest is Test {
    Masterchef public masterchef;
    Masterchad public masterchad;
    MockERC20 public token;
    MockERC20 public lpToken1;
    MockERC20 public lpToken2;

    address public alice;
    address public bob;

    uint256 public tokenPerBlock = 1e18;
    uint256 public startBlock;
    uint256 public bonusEndBlock;

    function setUp() public {
        // Setup accounts.
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Create token and LP tokens.
        token = new MockERC20("Reward Token", "REWARD", 0);
        lpToken1 = new MockERC20("LP Token 1", "LP1", 1000000 ether);
        lpToken2 = new MockERC20("LP Token 2", "LP2", 1000000 ether);

        console2.log("lpToken1", address(lpToken1));
        console2.log("lpToken2", address(lpToken2));

        // Setup block numbers.
        startBlock = block.number;

        // Deploy Masterchef and Masterchad.
        masterchef = new Masterchef(address(token), address(this), tokenPerBlock, startBlock);
        masterchad = new Masterchad(address(token), address(this), tokenPerBlock, startBlock);

        // Setup initial pools.
        masterchef.add(1000, IERC20(address(lpToken1)));
        masterchad.add(1000, address(lpToken1));

        masterchef.add(2000, IERC20(address(lpToken2)));
        masterchad.add(2000, address(lpToken2));

        // Distribute LP tokens to users.
        lpToken1.transfer(alice, 1000 ether);
        lpToken1.transfer(bob, 1000 ether);
        lpToken2.transfer(alice, 1000 ether);
        lpToken2.transfer(bob, 1000 ether);

        // Approve all tokens.
        vm.startPrank(alice);
        token.approve(address(masterchef), type(uint256).max);
        lpToken1.approve(address(masterchef), type(uint256).max);
        lpToken2.approve(address(masterchef), type(uint256).max);
        token.approve(address(masterchad), type(uint256).max);
        lpToken1.approve(address(masterchad), type(uint256).max);
        lpToken2.approve(address(masterchad), type(uint256).max);

        vm.startPrank(bob);
        token.approve(address(masterchef), type(uint256).max);
        lpToken1.approve(address(masterchef), type(uint256).max);
        lpToken2.approve(address(masterchef), type(uint256).max);
        token.approve(address(masterchad), type(uint256).max);
        lpToken1.approve(address(masterchad), type(uint256).max);
        lpToken2.approve(address(masterchad), type(uint256).max);
        vm.stopPrank();

        // Check deployment integrity.
        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, bob);
    }

    function test_basicDepositMasterchef() public {
        vm.prank(alice);
        masterchef.deposit(0, 1000 ether);

        vm.roll(block.number + 1);

        uint256 beforeBalanceAlice = token.balanceOf(alice);

        vm.prank(alice);
        masterchef.withdraw(0, 1000 ether);

        uint256 afterBalanceAlice = token.balanceOf(alice);

        console2.log("beforeBalanceAlice", beforeBalanceAlice);
        console2.log("afterBalanceAlice", afterBalanceAlice);
        assertLt(beforeBalanceAlice, afterBalanceAlice);
    }

    function test_basicDepositMasterchad() public {
        vm.prank(alice);
        masterchad.deposit(0, 1000 ether);

        vm.roll(block.number + 1);

        uint256 beforeBalanceAlice = token.balanceOf(alice);

        vm.prank(alice);
        masterchad.withdraw(0, 1000 ether);

        uint256 afterBalanceAlice = token.balanceOf(alice);

        console2.log("beforeBalanceAlice", beforeBalanceAlice);
        console2.log("afterBalanceAlice", afterBalanceAlice);
        // assertLt(beforeBalanceAlice, afterBalanceAlice);
    }

    function test_basicDiff(uint256 _amount) public {
        _amount = bound(_amount, 1 ether, 100 ether);
        // uint256 _amount = 100 ether;

        vm.prank(alice);
        masterchef.deposit(0, _amount);

        vm.prank(alice);
        masterchad.deposit(0, _amount);

        storageIntegrityCheck(0, alice);

        vm.roll(block.number + 1);

        masterchef.updatePool(0);
        masterchad.updatePool(0);

        logStorageMasterchef(0, alice);
        logStorageMasterchad(0, alice);
        storageIntegrityCheck(0, alice);

        vm.prank(alice);
        masterchef.withdraw(0, _amount);

        vm.prank(alice);
        masterchad.withdraw(0, _amount);

        storageIntegrityCheck(0, alice);
    }

    function test_multipleUsersDiff(uint256 _amount1, uint256 _amount2) public {
        _amount1 = bound(_amount1, 1 ether, 100 ether);
        _amount2 = bound(_amount2, 1 ether, 100 ether);

        // uint256 _amount1 = 100 ether;
        // uint256 _amount2 = 200 ether;

        vm.prank(alice);
        masterchef.deposit(0, _amount1);
        vm.prank(bob);
        masterchef.deposit(0, _amount2);

        vm.prank(alice);
        masterchad.deposit(0, _amount1);
        vm.prank(bob);
        masterchad.deposit(0, _amount2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        vm.roll(block.number + 1);

        masterchef.updatePool(0);
        masterchad.updatePool(0);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);

        vm.prank(alice);
        masterchef.withdraw(0, _amount1);
        vm.prank(bob);
        masterchef.withdraw(0, _amount2);

        vm.prank(alice);
        masterchad.withdraw(0, _amount1);
        vm.prank(bob);
        masterchad.withdraw(0, _amount2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
    }

    function test_multipleUsersAndPoolsDiff(uint256 _amount1, uint256 _amount2) public {
        _amount1 = bound(_amount1, 1 ether, 100 ether);
        _amount2 = bound(_amount2, 1 ether, 100 ether);

        // uint256 _amount1 = 100 ether;
        // uint256 _amount2 = 200 ether;

        vm.prank(alice);
        masterchef.deposit(0, _amount1);
        vm.prank(bob);
        masterchef.deposit(0, _amount2);

        vm.prank(alice);
        masterchad.deposit(0, _amount1);
        vm.prank(bob);
        masterchad.deposit(0, _amount2);

        vm.prank(alice);
        masterchef.deposit(1, _amount1);
        vm.prank(bob);
        masterchef.deposit(1, _amount2);

        vm.prank(alice);
        masterchad.deposit(1, _amount1);
        vm.prank(bob);
        masterchad.deposit(1, _amount2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);

        vm.roll(block.number + 1);

        masterchef.updatePool(0);
        masterchad.updatePool(0);
        masterchef.updatePool(1);
        masterchad.updatePool(1);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);

        vm.prank(alice);
        masterchef.withdraw(0, _amount1);
        vm.prank(bob);
        masterchef.withdraw(0, _amount2);

        vm.prank(alice);
        masterchad.withdraw(0, _amount1);
        vm.prank(bob);
        masterchad.withdraw(0, _amount2);

        vm.prank(alice);
        masterchef.withdraw(1, _amount1);
        vm.prank(bob);
        masterchef.withdraw(1, _amount2);

        vm.prank(alice);
        masterchad.withdraw(1, _amount1);
        vm.prank(bob);
        masterchad.withdraw(1, _amount2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);
    }

    function test_multipleUsersAndPoolsDiff2(uint256 _amount1, uint256 _amount2) public {
        _amount1 = bound(_amount1, 1 ether, 100 ether);
        _amount2 = bound(_amount2, 1 ether, 100 ether);

        // uint256 _amount1 = 100 ether;
        // uint256 _amount2 = 200 ether;

        vm.prank(alice);
        masterchef.deposit(0, _amount1);
        vm.prank(bob);
        masterchef.deposit(0, _amount2);

        vm.prank(alice);
        masterchad.deposit(0, _amount1);
        vm.prank(bob);
        masterchad.deposit(0, _amount2);

        vm.prank(alice);
        masterchef.deposit(1, _amount1);
        vm.prank(bob);
        masterchef.deposit(1, _amount2);

        vm.prank(alice);
        masterchad.deposit(1, _amount1);
        vm.prank(bob);
        masterchad.deposit(1, _amount2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);

        vm.roll(block.number + 10);

        masterchef.updatePool(0);
        masterchad.updatePool(0);
        masterchef.updatePool(1);
        masterchad.updatePool(1);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);

        vm.prank(alice);
        masterchef.withdraw(0, _amount1);
        vm.prank(bob);
        masterchef.withdraw(0, _amount2 / 2);

        vm.prank(alice);
        masterchad.withdraw(0, _amount1);
        vm.prank(bob);
        masterchad.withdraw(0, _amount2 / 2);

        vm.prank(alice);
        masterchef.withdraw(1, _amount1);
        vm.prank(bob);
        masterchef.withdraw(1, _amount2 / 2);

        vm.prank(alice);
        masterchad.withdraw(1, _amount1);
        vm.prank(bob);
        masterchad.withdraw(1, _amount2 / 2);

        storageIntegrityCheck(0, alice);
        storageIntegrityCheck(0, bob);
        storageIntegrityCheck(1, alice);
        storageIntegrityCheck(1, bob);
    }

    // ======= Helpers =======

    struct HelperStorage {
        uint256 amount;
        uint256 rewardDebt;
        uint256 poolLength;
        address lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokenPerShare;
    }

    function storageIntegrityCheck(uint256 _pid, address _user) public view {
        HelperStorage memory storage1_;
        (storage1_.amount, storage1_.rewardDebt) = masterchef.getUserInfo(_pid, _user);
        (
            storage1_.poolLength,
            storage1_.lpToken,
            storage1_.allocPoint,
            storage1_.lastRewardBlock,
            storage1_.accTokenPerShare
        ) = masterchef.getPoolInfo(_pid);

        HelperStorage memory storage2_;
        (storage2_.amount, storage2_.rewardDebt) = masterchad.getUserInfo(_pid, _user);
        (
            storage2_.poolLength,
            storage2_.lpToken,
            storage2_.allocPoint,
            storage2_.lastRewardBlock,
            storage2_.accTokenPerShare
        ) = masterchad.getPoolInfo(_pid);

        assertEq(storage1_.amount, storage2_.amount, "1");
        assertEq(storage1_.rewardDebt, storage2_.rewardDebt, "2");
        assertEq(storage1_.poolLength, storage2_.poolLength, "3");
        assertEq(storage1_.lpToken, storage2_.lpToken, "4");
        assertEq(storage1_.allocPoint, storage2_.allocPoint, "5");
        assertEq(storage1_.lastRewardBlock, storage2_.lastRewardBlock, "6");
        assertEq(storage1_.accTokenPerShare, storage2_.accTokenPerShare, "7");
        assertEq(token.balanceOf(address(masterchef)), token.balanceOf(address(masterchad)), "8");
        assertEq(lpToken1.balanceOf(address(masterchef)), lpToken1.balanceOf(address(masterchad)), "9");
        // assertEq(lpToken2.balanceOf(masterchef), lpToken2.balanceOf(masterchad), "10");
    }

    function logStorageMasterchef(uint256 _pid, address _user) public view {
        HelperStorage memory storage_;

        (storage_.amount, storage_.rewardDebt) = masterchef.getUserInfo(_pid, _user);
        (
            storage_.poolLength,
            storage_.lpToken,
            storage_.allocPoint,
            storage_.lastRewardBlock,
            storage_.accTokenPerShare
        ) = masterchef.getPoolInfo(_pid);

        console2.log("amount            ::: ", storage_.amount);
        console2.log("rewardDebt        ::: ", storage_.rewardDebt);
        console2.log("poolLength        ::: ", storage_.poolLength);
        console2.log("lpToken           ::: ", storage_.lpToken);
        console2.log("allocPoint        ::: ", storage_.allocPoint);
        console2.log("lastRewardBlock   ::: ", storage_.lastRewardBlock);
        console2.log("accTokenPerShare  ::: ", storage_.accTokenPerShare);
        console2.log("--------------------------------");
    }

    function logStorageMasterchad(uint256 _pid, address _user) public view {
        HelperStorage memory storage_;

        (storage_.amount, storage_.rewardDebt) = masterchad.getUserInfo(_pid, _user);
        (
            storage_.poolLength,
            storage_.lpToken,
            storage_.allocPoint,
            storage_.lastRewardBlock,
            storage_.accTokenPerShare
        ) = masterchad.getPoolInfo(_pid);

        console2.log("amount            ::: ", storage_.amount);
        console2.log("rewardDebt        ::: ", storage_.rewardDebt);
        console2.log("poolLength        ::: ", storage_.poolLength);
        console2.log("lpToken           ::: ", storage_.lpToken);
        console2.log("allocPoint        ::: ", storage_.allocPoint);
        console2.log("lastRewardBlock   ::: ", storage_.lastRewardBlock);
        console2.log("accTokenPerShare  ::: ", storage_.accTokenPerShare);
        console2.log("--------------------------------");
    }
}
