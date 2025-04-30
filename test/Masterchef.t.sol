// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.23;

// import {Test, console} from "forge-std/Test.sol";
// import "../src/Masterchef.sol";
// import "../src/utils/MockERC20.sol";
// import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// contract MasterchefTest is Test {
//     Masterchef public masterchef;
//     MockERC20 public token;
//     MockERC20 public lpToken1;
//     MockERC20 public lpToken2;

//     address public owner;
//     address public dev;
//     address public alice;
//     address public bob;

//     uint256 public tokenPerBlock = 100 ether;
//     uint256 public startBlock;
//     uint256 public bonusEndBlock;

//     function setUp() public {
//         // Setup accounts
//         owner = makeAddr("owner");
//         dev = makeAddr("dev");
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");

//         vm.startPrank(owner);

//         // Create token and LP tokens
//         token = new MockERC20("Reward Token", "REWARD", 0);
//         lpToken1 = new MockERC20("LP Token 1", "LP1", 1000000 ether);
//         lpToken2 = new MockERC20("LP Token 2", "LP2", 1000000 ether);

//         // Setup block numbers
//         startBlock = block.number + 100;
//         bonusEndBlock = startBlock + 100;

//         // Deploy Masterchef
//         masterchef = new Masterchef(
//             token,
//             dev,
//             tokenPerBlock,
//             startBlock,
//             bonusEndBlock
//         );

//         // Transfer ownership of token to Masterchef
//         token.transferOwnership(address(masterchef));

//         // Setup initial pools
//         masterchef.add(1000, IERC20(address(lpToken1)), true);
//         masterchef.add(2000, IERC20(address(lpToken2)), true);

//         // Distribute LP tokens to users
//         lpToken1.transfer(alice, 1000 ether);
//         lpToken1.transfer(bob, 1000 ether);
//         lpToken2.transfer(alice, 1000 ether);
//         lpToken2.transfer(bob, 1000 ether);

//         vm.stopPrank();
//     }

//     function test_PoolLength() public {
//         assertEq(masterchef.poolLength(), 2);
//     }

//     function test_PoolInfo() public {
//         (IERC20 lpToken, uint256 allocPoint, , ) = masterchef.poolInfo(0);
//         assertEq(address(lpToken), address(lpToken1));
//         assertEq(allocPoint, 1000);

//         (lpToken, allocPoint, , ) = masterchef.poolInfo(1);
//         assertEq(address(lpToken), address(lpToken2));
//         assertEq(allocPoint, 2000);
//     }

//     function test_TotalAllocPoint() public {
//         assertEq(masterchef.totalAllocPoint(), 3000);
//     }

//     function test_UpdatePool() public {
//         vm.roll(startBlock + 10); // Move to a block after startBlock
//         masterchef.updatePool(0);

//         (, , uint256 lastRewardBlock, uint256 accTokenPerShare) = masterchef.poolInfo(0);
//         assertEq(lastRewardBlock, block.number);
//         assertEq(accTokenPerShare, 0); // No deposits yet
//     }

//     function test_Deposit() public {
//         // Approve and deposit LP tokens
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         masterchef.deposit(0, 100 ether);
//         vm.stopPrank();

//         // Check user info
//         (uint256 amount, ) = masterchef.userInfo(0, alice);
//         assertEq(amount, 100 ether);

//         // Check LP token balance
//         assertEq(lpToken1.balanceOf(address(masterchef)), 100 ether);
//     }

//     function test_PendingTokens() public {
//         // Alice deposits LP tokens
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         masterchef.deposit(0, 100 ether);
//         vm.stopPrank();

//         // Advance some blocks past startBlock
//         vm.roll(startBlock + 10);

//         // Check pending rewards
//         uint256 pending = masterchef.pendingToken(0, alice);
//         assertGt(pending, 0);
//     }

//     function test_Withdraw() public {
//         // Alice deposits LP tokens
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         masterchef.deposit(0, 100 ether);

//         // Advance some blocks
//         vm.roll(startBlock + 10);

//         // Get initial token balance
//         uint256 initialTokenBalance = token.balanceOf(alice);

//         // Withdraw all LP tokens
//         masterchef.withdraw(0, 100 ether);
//         vm.stopPrank();

//         // Check user info
//         (uint256 amount, ) = masterchef.userInfo(0, alice);
//         assertEq(amount, 0);

//         // Check LP token returned
//         assertEq(lpToken1.balanceOf(alice), 1000 ether);

//         // Check rewards received
//         assertGt(token.balanceOf(alice), initialTokenBalance);
//     }

//     function test_MultiplePools() public {
//         // Alice and Bob deposit in different pools
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         masterchef.deposit(0, 100 ether);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         lpToken2.approve(address(masterchef), 100 ether);
//         masterchef.deposit(1, 100 ether);
//         vm.stopPrank();

//         // Advance some blocks
//         vm.roll(startBlock + 20);

//         // Check pending rewards
//         uint256 alicePending = masterchef.pendingToken(0, alice);
//         uint256 bobPending = masterchef.pendingToken(1, bob);

//         // Bob should have twice as many rewards (pool 1 has 2000 allocation points vs 1000)
//         assertGt(bobPending, alicePending);
//         assertEq(bobPending, alicePending * 2);
//     }

//     function test_BonusMultiplier() public {
//         // Alice deposits before bonus period ends
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         vm.roll(startBlock + 10); // During bonus period
//         masterchef.deposit(0, 100 ether);

//         // Advance to the end of the bonus period
//         uint256 rewardDuringBonus = masterchef.pendingToken(0, alice);
//         vm.roll(bonusEndBlock + 10); // After bonus period
//         uint256 totalReward = masterchef.pendingToken(0, alice);

//         // Rewards during bonus period should be significantly higher
//         assertGt(rewardDuringBonus, 0);
//         assertGt(totalReward, rewardDuringBonus);
//         vm.stopPrank();
//     }

//     function test_SetAllocationPoints() public {
//         // Only owner can call set
//         vm.prank(owner);
//         masterchef.set(0, 3000, true);

//         // Check updated allocation points
//         (, uint256 allocPoint, , ) = masterchef.poolInfo(0);
//         assertEq(allocPoint, 3000);

//         // Check totalAllocPoint was updated correctly
//         assertEq(masterchef.totalAllocPoint(), 5000); // 3000 + 2000
//     }

//     function test_EmergencyWithdraw() public {
//         // Alice deposits LP tokens
//         vm.startPrank(alice);
//         lpToken1.approve(address(masterchef), 100 ether);
//         masterchef.deposit(0, 100 ether);

//         // Emergency withdraw
//         masterchef.withdraw(0, 100 ether);
//         vm.stopPrank();

//         // Check user amount is 0
//         (uint256 amount, ) = masterchef.userInfo(0, alice);
//         assertEq(amount, 0);

//         // Check LP tokens returned
//         assertEq(lpToken1.balanceOf(alice), 1000 ether);
//     }

//     function test_SetDev() public {
//         address newDev = makeAddr("newDev");

//         // Only owner can set dev
//         vm.prank(owner);
//         masterchef.setDev(newDev);

//         // Check dev address was updated
//         assertEq(masterchef.devaddr(), newDev);
//     }
// }
