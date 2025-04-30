// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/solady/src/utils/SafeTransferLib.sol";
import "lib/solady/src/auth/Ownable.sol";
import {IERC20Mintable} from "./interfaces/IERC20.sol";

contract Masterchad is Ownable {
    using SafeTransferLib for address;

    // Structs

    // struct UserInfo {
    //     uint256 amount;
    //     uint256 rewardDebt;
    // }

    // struct PoolInfo {
    //     address lpToken;
    //     uint64 allocPoint;
    //     uint32 lastRewardBlock;
    //     uint256 accTokenPerShare;
    // }

    // Storage

    uint256 private constant WAD = 1e18;
    uint256 private constant MAX_POOL_NUMBER = 255; // Set to type(uint8.max).
    uint256 private constant MAX_ALLOCATION_POINT = 18446744073709551615; // Set to type(uint64.max).

    uint256 private constant _TOKEN_SLOT = 0x9cf069ec1f46db069f;
    uint256 private constant _TOKEN_PER_BLOCK_SLOT = 0xdcf9ea19e9d4baeda8;
    uint256 private constant _TOTAL_ALLOC_POINT_SLOT = 0x0d8e8be0eec8ca51f2;
    uint256 private constant _START_BLOCK_SLOT = 0x25e5d9d7ba4b9cd642;

    /**
     * @dev set:
     *          let poolInfoSize_ := sload(_POOL_INFO_SEED_SLOT)
     *          sstore(_POOL_INFO_SEED_SLOT, add(poolInfoSize_, 1))
     *          mstore(0x20, _POOL_INFO_SEED_SLOT)
     *          mstore(0x1c, poolInfoSize_)
     *
     *          let key_ := keccak256(0x1c, 0x05)
     *          sstore(key_, add(shl(96, _lpToken), add(shl(32, _allocPoint), lastRewardBlock_)))
     *          sstore(add(key_, 0x20), 0)
     */
    uint256 private constant _POOL_INFO_SEED_SLOT = 0x070868d5; // Mapping of PoolInfo. The size of the mapping is stored in _POOL_INFO_MASTER_SLOT.

    /**
     * @dev set:
     *          mstore(0x05, _pid)
     *          mstore(0x04, _USER_INFO_SEED_SLOT)
     *          mstore(0x00, _user)
     *
     *          let key_ := keccak256(0x0d, 0x19)
     *          sstore(key_, _amount)
     *          sstore(add(key_, 0x20), _rewardDebt)
     */
    uint256 private constant _USER_INFO_SEED_SLOT = 0x1766266e; // Mapping of UserInfo

    // Errors

    /// @dev `keccak256(bytes("Masterchad__MAX_NUMBER_OF_POOL_REACHED()"))`.
    error Masterchad__MAX_NUMBER_OF_POOL_REACHED();

    uint256 private constant _ERROR_MAX_NUMBER_OF_POOL_REACHED = 0x917bdbed;

    /// @dev `keccak256(bytes("Masterchad__MAX_ALLOCATION_POINT_REACHED()"))`.
    error Masterchad__MAX_ALLOCATION_POINT_REACHED();

    uint256 private constant _ERROR_MAX_ALLOCATION_POINT_REACHED = 0xa78c0319;

    // Events

    /// @dev `keccak256(bytes("Deposit(address,uint256,uint256)"))`.
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    uint256 private constant _EVENT_DEPOSIT_SIGNATURE =
        0x90890809c654f11d6e72a28fa60149770a0d11ec6c92319d6ceb2bb0a4ea1a15;

    /// @dev `keccak256(bytes("Withdraw(address,uint256,uint256)"))`.
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    uint256 private constant _EVENT_WITHDRAW_SIGNATURE =
        0xf279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568;

    constructor(address _token, address _admin, uint256 _tokenPerBlock, uint256 _startBlock) {
        _initializeOwner(_admin);

        assembly {
            sstore(_TOKEN_SLOT, _token)
            sstore(_TOKEN_PER_BLOCK_SLOT, _tokenPerBlock)
            sstore(_START_BLOCK_SLOT, _startBlock)
        }
    }

    /// ======== onlyOwner ========

    function add(uint256 _allocPoint, address _lpToken) public onlyOwner {
        assembly {
            let startBlock_ := sload(_START_BLOCK_SLOT)
            let lastRewardBlock_

            switch gt(number(), startBlock_)
            case 1 { lastRewardBlock_ := startBlock_ }
            default { lastRewardBlock_ := number() }

            // Store total allocation point.
            sstore(_TOTAL_ALLOC_POINT_SLOT, add(sload(_TOTAL_ALLOC_POINT_SLOT), _allocPoint))

            let poolInfoSize_ := sload(_POOL_INFO_SEED_SLOT)

            // Checking if the number of pools exceeds the limit.
            if gt(add(poolInfoSize_, 1), MAX_POOL_NUMBER) {
                mstore(0x00, _ERROR_MAX_NUMBER_OF_POOL_REACHED)
                revert(0x1c, 0x04)
            }

            // Checking if total allocation point exceeds the limit.
            if gt(_allocPoint, MAX_ALLOCATION_POINT) {
                mstore(0x00, _ERROR_MAX_ALLOCATION_POINT_REACHED)
                revert(0x1c, 0x04)
            }

            // Updating the size of the poolInfo array.
            sstore(_POOL_INFO_SEED_SLOT, add(poolInfoSize_, 1))

            // Calculating the key for the poolInfo.
            mstore(0x20, _POOL_INFO_SEED_SLOT)
            mstore(0x1c, poolInfoSize_)
            let poolInfoKey_ := keccak256(0x1c, 0x05)

            // Pack and Store the poolInfo.
            sstore(poolInfoKey_, add(shl(96, _lpToken), add(shl(32, _allocPoint), lastRewardBlock_)))
            sstore(add(poolInfoKey_, 0x20), 0)
        }
    }

    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        assembly {
            // Checking if total allocation point exceeds the limit.
            if gt(_allocPoint, MAX_ALLOCATION_POINT) {
                mstore(0x00, _ERROR_MAX_ALLOCATION_POINT_REACHED)
                revert(0x1c, 0x04)
            }

            mstore(0x20, _POOL_INFO_SEED_SLOT)
            mstore(0x1c, _pid)
            let poolInfoKey_ := keccak256(0x1c, 0x05)

            let poolInfoSlot0_ := sload(poolInfoKey_)
            let allocPoint_ := shr(32, poolInfoSlot0_)

            // Update total allocation point.
            let totalAllocationPoint_ := sload(_TOTAL_ALLOC_POINT_SLOT)
            sstore(_TOTAL_ALLOC_POINT_SLOT, add(sub(totalAllocationPoint_, allocPoint_), _allocPoint))

            // Update pool info.
            let mask_ := shl(32, _allocPoint)
            poolInfoSlot0_ := and(poolInfoSlot0_, 0xffffffffffffffffffffffffffffffffffffffff0000000000000000ffffffff)
            sstore(poolInfoKey_, or(poolInfoSlot0_, mask_))
        }
    }

    function massUpdatePools() public {
        uint256 poolInfoSize_;
        assembly {
            poolInfoSize_ := sload(_POOL_INFO_SEED_SLOT)
        }

        for (uint256 i; i < poolInfoSize_; ++i) {
            updatePool(i);
        }
    }

    function updatePool(uint256 _pid) public {
        uint256 tokenReward_;

        assembly {
            mstore(0x20, _POOL_INFO_SEED_SLOT)
            mstore(0x1c, _pid)
            let poolInfoKeySlot0_ := keccak256(0x1c, 0x05)
            let poolInfoSlot0_ := sload(poolInfoKeySlot0_)
            let lastRewardBlock_ := shr(224, shl(224, poolInfoSlot0_))

            // block.number > pool.lastRewardBlock
            if gt(number(), lastRewardBlock_) {
                let lpToken_ := shr(96, poolInfoSlot0_)
                mstore(0x00, 0x70a08231) // 0x70a08231 ::: balanceOf(address)
                mstore(0x20, address())

                let success_ := staticcall(gas(), lpToken_, 0x1c, 0x24, 0x00, 0x20)
                if iszero(success_) { revert(0x00, 0x00) }
                let lpSupply_ := mload(0x00)

                switch lpSupply_
                case 0 {
                    poolInfoSlot0_ :=
                        and(poolInfoSlot0_, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000)
                    sstore(poolInfoKeySlot0_, or(poolInfoSlot0_, number()))
                }
                default {
                    let multiplier_ := sub(number(), lastRewardBlock_)
                    tokenReward_ := div(mul(multiplier_, mul(sload(_TOKEN_PER_BLOCK_SLOT), WAD)), lpSupply_)

                    // Update pool.accTokenPerShare.
                    let poolInfoKeySlot1_ := add(poolInfoKeySlot0_, 0x20)
                    sstore(poolInfoKeySlot1_, add(sload(poolInfoKeySlot1_), div(mul(tokenReward_, WAD), lpSupply_)))

                    // Update pool.lastRewardBlock.
                    poolInfoSlot0_ :=
                        and(poolInfoSlot0_, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000)
                    sstore(poolInfoKeySlot0_, or(poolInfoSlot0_, number()))
                }
            }
        }

        if (tokenReward_ != 0) {
            address token_;
            assembly {
                token_ := sload(_TOKEN_SLOT)
            }
            IERC20Mintable(token_).mint(address(this), tokenReward_);
        }
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        updatePool(_pid);

        assembly {}
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        updatePool(_pid);

        assembly {}
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal_;
        address token_;
        assembly {
            token_ := sload(_TOKEN_SLOT)

            mstore(0x00, 0x70a08231) // 0x70a08231 ::: balanceOf(address)
            mstore(0x20, address())

            let success_ := staticcall(gas(), token_, 0x1c, 0x24, 0x00, 0x20)
            if iszero(success_) { revert(0x00, 0x00) }
            tokenBal_ := mload(0x00)
        }

        // Using Solady gas efficient SafeTransferLib.
        if (_amount > tokenBal_) {
            token_.safeTransfer(_to, tokenBal_);
        } else {
            token_.safeTransfer(_to, _amount);
        }
    }

    /// ======== onlyOwner ========

    /// ======== Views ========

    function readStorage(uint256 _slot) public view returns (uint256 ret_) {
        assembly {
            ret_ := sload(_slot)
        }
    }

    function getPoolInfo(uint256 _pid)
        public
        view
        returns (
            uint256 size_,
            address lpToken_,
            uint64 allocPoint_,
            uint32 lastRewardBlock_,
            uint256 accTokenPerShare_
        )
    {
        assembly {
            mstore(0x20, _POOL_INFO_SEED_SLOT)
            mstore(0x1c, _pid)
            let poolInfoKey_ := keccak256(0x1c, 0x05)

            let infoPoolSlot1_ := sload(poolInfoKey_)
            size_ := sload(_POOL_INFO_SEED_SLOT)
            lpToken_ := shr(96, infoPoolSlot1_)
            allocPoint_ := shr(32, infoPoolSlot1_)
            lastRewardBlock_ := infoPoolSlot1_
            accTokenPerShare_ := sload(add(poolInfoKey_, 0x20))
        }
    }

    function getUserInfo(uint256 _pid, address _user) public view returns (int256 amount_, uint256 rewardDebt_) {
        assembly {
            mstore(0x05, _pid)
            mstore(0x04, _USER_INFO_SEED_SLOT)
            mstore(0x00, _user)

            let userInfoKey_ := keccak256(0x0d, 0x19)
            amount_ := sload(userInfoKey_)
            rewardDebt_ := sload(add(userInfoKey_, 0x20))
        }
    }

    // todo ======== DEBUG TO DELETE ========
    function setUserInfo(uint256 _pid, address _user, int256 _amount, uint256 _rewardDebt) public {
        assembly {
            mstore(0x05, _pid)
            mstore(0x04, _USER_INFO_SEED_SLOT)
            mstore(0x00, _user)

            let userInfoKey_ := keccak256(0x0d, 0x19)
            sstore(userInfoKey_, _amount)
            sstore(add(userInfoKey_, 0x20), _rewardDebt)
        }
    }
}
