// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20Mintable} from "./interfaces/IERC20.sol";

// MasterChef is the master of Token. He can make Token and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once TOKEN is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Masterchef is Ownable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. TOKENs to distribute per block.
        uint256 lastRewardBlock; // Last block number that TOKENs distribution occurs.
        uint256 accTokenPerShare; // Accumulated TOKENs per share, times PRECISION. See below.
    }

    // Precision for precision math
    uint256 private constant PRECISION = 1e18;

    // The TOKEN TOKEN!
    IERC20 public token;
    // Dev address.
    address public admin;
    // TOKEN tokens created per block.
    uint256 public tokenPerBlock;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when TOKEN mining starts.
    uint256 public startBlock;

    // Info of each pool.
    PoolInfo[] internal poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) internal userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(IERC20 _token, address _admin, uint256 _tokenPerBlock, uint256 _startBlock) Ownable(_admin) {
        token = _token;
        admin = _admin;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
    }

    function add(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner {
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({lpToken: _lpToken, allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accTokenPerShare: 0})
        );
    }

    // Update the given pool's TOKEN allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending TOKENs on frontend.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 tokenReward = multiplier * tokenPerBlock * pool.allocPoint / totalAllocPoint;

            accTokenPerShare = accTokenPerShare + (tokenReward * PRECISION / lpSupply);
        }
        return (user.amount * accTokenPerShare / PRECISION) - user.rewardDebt;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 tokenReward = multiplier * tokenPerBlock * pool.allocPoint / totalAllocPoint;

        IERC20Mintable(address(token)).mint(address(this), tokenReward);

        pool.accTokenPerShare = (pool.accTokenPerShare + tokenReward) * PRECISION / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for TOKEN allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accTokenPerShare / PRECISION - user.rewardDebt;
            safeTokenTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount + _amount;
        user.rewardDebt = user.amount * pool.accTokenPerShare / PRECISION;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount * pool.accTokenPerShare / PRECISION - user.rewardDebt;
        safeTokenTransfer(msg.sender, pending);
        user.amount = user.amount - _amount;
        user.rewardDebt = user.amount * pool.accTokenPerShare / PRECISION;
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough TOKENs.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.safeTransfer(_to, tokenBal);
        } else {
            token.safeTransfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function setDev(address _admin) public onlyOwner {
        admin = _admin;
    }

    /// getter
    function getPoolInfo(uint256 _pid) public view returns (address, uint256, uint256, uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return (address(pool.lpToken), pool.allocPoint, pool.lastRewardBlock, pool.accTokenPerShare);
    }

    function getUserInfo(uint256 _pid, address _user) public view returns (uint256, uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return (user.amount, user.rewardDebt);
    }
}
