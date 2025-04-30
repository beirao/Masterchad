// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Masterchef.sol";
import "../src/utils/MockERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MasterchefTest is Test {
    Masterchef public masterchef;
    MockERC20 public token;
    MockERC20 public lpToken1;
    MockERC20 public lpToken2;

    address public owner;
    address public dev;
    address public alice;
    address public bob;

    uint256 public tokenPerBlock = 100 ether;
    uint256 public startBlock;
    uint256 public bonusEndBlock;

    function setUp() public {
        // Setup accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Create token and LP tokens
        token = new MockERC20("Reward Token", "REWARD", 0);
        lpToken1 = new MockERC20("LP Token 1", "LP1", 1000000 ether);
        lpToken2 = new MockERC20("LP Token 2", "LP2", 1000000 ether);

        // Setup block numbers
        startBlock = block.number;

        // Deploy Masterchef
        masterchef = new Masterchef(address(token), address(this), 10000, startBlock);

        // Transfer ownership of token to Masterchef
        token.transferOwnership(address(masterchef));

        // Setup initial pools
        lpToken1.transfer(address(masterchef), 1000 ether);
        masterchef.add(1000, IERC20(address(lpToken1)));
        //    masterchef.add(2000, IERC20(address(lpToken2)));

        // Distribute LP tokens to users
        lpToken1.transfer(alice, 1000 ether);
        lpToken1.transfer(bob, 1000 ether);
        lpToken2.transfer(alice, 1000 ether);
        lpToken2.transfer(bob, 1000 ether);

        // approve all tokens
        vm.startPrank(alice);
        token.approve(address(masterchef), type(uint256).max);
        lpToken1.approve(address(masterchef), type(uint256).max);
        lpToken2.approve(address(masterchef), type(uint256).max);

        vm.startPrank(bob);
        token.approve(address(masterchef), type(uint256).max);
        lpToken1.approve(address(masterchef), type(uint256).max);
        lpToken2.approve(address(masterchef), type(uint256).max);
        vm.stopPrank();
    }

    function test_deposit() public {
        vm.prank(alice);
        masterchef.deposit(0, 1000 ether);

        vm.prank(bob);
        masterchef.deposit(0, 1000 ether);

        vm.roll(block.number + 3);

        uint256 beforeBalance = lpToken1.balanceOf(alice);

        vm.prank(alice);
        masterchef.withdraw(0, 1000 ether / 2);

        uint256 afterBalance = lpToken1.balanceOf(alice);

        console2.log("beforeBalance", beforeBalance);
        console2.log("afterBalance", afterBalance);
    }
}
