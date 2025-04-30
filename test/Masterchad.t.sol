// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Masterchad.sol";
import {MockERC20} from "../src/utils/MockERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MasterchadTest is Test {
    // storage slots ----
    uint256 private constant _TOKEN_SLOT = 0x9cf069ec1f46db069f;
    uint256 private constant _ADMIN_SLOT = 0x6ba677f1cdbe0f40f1;
    uint256 private constant _TOKEN_PER_BLOCK_SLOT = 0xdcf9ea19e9d4baeda8;
    uint256 private constant _TOTAL_ALLOC_POINT_SLOT = 0x0d8e8be0eec8ca51f2;
    uint256 private constant _START_BLOCK_SLOT = 0x25e5d9d7ba4b9cd642;

    uint256 private constant _POOL_INFO_SEED_SLOT = 0x070868d5; // Mapping/Array of PoolInfo. The size of the array is stored in _POOL_INFO_MASTER_SLOT.
    uint256 private constant _USER_INFO_SEED_SLOT = 0x1766266e; // Mapping of UserInfo
    // ----

    Masterchad public masterchad;
    MockERC20 public token;
    MockERC20 public lpToken1;
    MockERC20 public lpToken2;

    address public owner;
    address public dev;
    address public alice;
    address public bob;

    uint256 public tokenPerBlock = 100 ether;
    uint256 public allocPoint = 1000;
    uint256 public startBlock;
    uint256 public bonusEndBlock;

    function setUp() public {
        // Setup accounts
        owner = makeAddr("owner");
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.startPrank(owner);

        // Create token and LP tokens
        token = new MockERC20("Reward Token", "REWARD", 0);
        lpToken1 = new MockERC20("LP Token 1", "LP1", 1000000 ether);
        lpToken2 = new MockERC20("LP Token 2", "LP2", 1000000 ether);

        // Setup block numbers
        startBlock = block.number + 100;

        // Deploy Masterchef
        masterchad = new Masterchad(address(token), address(this), 10000, startBlock);

        // Transfer ownership of token to Masterchef
        token.transferOwnership(address(masterchad));

        // Setup initial pools
        // masterchad.add(1000, IERC20(address(lpToken1)), true);
        // masterchad.add(2000, IERC20(address(lpToken2)), true);

        // Distribute LP tokens to users
        lpToken1.transfer(alice, 1000 ether);
        lpToken1.transfer(bob, 1000 ether);
        lpToken2.transfer(alice, 1000 ether);
        lpToken2.transfer(bob, 1000 ether);

        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(address(uint160(masterchad.readStorage(_TOKEN_SLOT))), address(token));
        assertEq(address(uint160(masterchad.readStorage(_ADMIN_SLOT))), address(owner));
        assertEq(masterchad.readStorage(_TOTAL_ALLOC_POINT_SLOT), allocPoint);
        assertEq(masterchad.readStorage(_START_BLOCK_SLOT), startBlock);
    }

    function test_add() public {
        masterchad.add(1000, address(lpToken1));
        (uint256 size_, address lpToken_, uint96 allocPoint_, uint256 lastRewardBlock_, uint256 accTokenPerShare_) =
            masterchad.getPoolInfo(0);

        console2.log(size_);
        console2.log(lpToken_);
        console2.log(allocPoint_);
        console2.log(lastRewardBlock_);
        console2.log(accTokenPerShare_);

        masterchad.add(220000, address(lpToken2));
        (size_, lpToken_, allocPoint_, lastRewardBlock_, accTokenPerShare_) = masterchad.getPoolInfo(1);

        console2.log(size_);
        console2.log(lpToken_);
        console2.log(allocPoint_);
        console2.log(lastRewardBlock_);
        console2.log(accTokenPerShare_);

        masterchad.set(0, 666);
        (size_, lpToken_, allocPoint_, lastRewardBlock_, accTokenPerShare_) = masterchad.getPoolInfo(1);

        console2.log(size_);
        console2.log(lpToken_);
        console2.log(allocPoint_);
        console2.log(lastRewardBlock_);
        console2.log(accTokenPerShare_);
    }

    function test_setUserInfo() public {
        masterchad.setUserInfo(255, alice, 1000, 1000);

        (int256 amount_, uint256 rewardDebt_) = masterchad.getUserInfo(255, alice);
        console2.log(amount_);
        console2.log(rewardDebt_);

        masterchad.setUserInfo(5, bob, 666, 666);

        (amount_, rewardDebt_) = masterchad.getUserInfo(5, bob);
        console2.log(amount_);
        console2.log(rewardDebt_);
    }
}
