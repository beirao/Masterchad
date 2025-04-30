// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../lib/solady/src/tokens/ERC20.sol";

// Create a test implementation of the abstract ERC20 contract
contract TestERC20 is ERC20 {
    constructor() {
        // Initialize the token
    }

    function name() public pure override returns (string memory) {
        return "Test Token";
    }

    function symbol() public pure override returns (string memory) {
        return "TEST";
    }

    // Expose the mint function for testing
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract ERC20Test is Test {
    TestERC20 public token;
    address public alice = address(0x1111111111111111111111111111111111111111);
    address public bob = address(0x2222222222222222222222222222222222222222);

    function setUp() public {
        token = new TestERC20();
        token.mint(alice, 1000 * 10 ** 18);
        token.mint(bob, 500 * 10 ** 18);

        vm.prank(alice);
        token.approve(bob, 1000 * 10 ** 18);
    }

    function test_balanceOf() public {
        uint256 a = token.balanceOf(alice);

        assertEq(a, 1000 * 10 ** 18);
        // assertEq(token.balanceOf(alice), 1000 * 10**18);
        // assertEq(token.balanceOf(bob), 500 * 10**18);
    }

    function test_allowance() public {
        uint256 a = token.allowance(alice, bob);

        assertEq(a, 0);
    }
}
