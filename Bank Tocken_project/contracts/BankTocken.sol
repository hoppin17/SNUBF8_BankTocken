// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract BankToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    address public nodeMaintainer;
    uint256 public constant NODE_REWARD = 10000 * 10 ** 8; // Adjusted to decimals (8)
    uint256 public constant REWARD_INTERVAL = 1 days;

    struct BankDeposit {
        uint256 amount;
        string bankId;
    }

    struct Node {
        uint256 lastRewardTime;
    }

    /* node와 bank 정보 mapping */
    mapping(address => BankDeposit[]) public deposits;
    mapping(address => Node) public nodes;

    /* Role definition for node maintainer */
    bytes32 public constant NODE_MAINTAINER_ROLE = keccak256("NODE_MAINTAINER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _nodeMaintainer) initializer public {
        __ERC20_init("BankToken", "BANK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __ERC20Permit_init("BankToken");
        __AccessControl_init();
        __Ownable_init(msg.sender);
        nodeMaintainer = _nodeMaintainer;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(NODE_MAINTAINER_ROLE, _nodeMaintainer);
    }

    function decimals() public view virtual override returns (uint8) {
        return 8; // Setting decimals to 8
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /* deposit func */
    function deposit(uint256 amount, string memory bankId) public {
        require(amount > 0, "Amount must be greater than zero");

        // Log the deposit
        deposits[msg.sender].push(BankDeposit({
            amount: amount,
            bankId: bankId
        }));

        // Mint the corresponding amount of tokens to the depositor
        _mint(msg.sender, amount * 10 ** decimals());
    }

    /* withdraw func */
    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        uint256 amountInBaseUnit = amount * 10 ** decimals();
        require(balanceOf(msg.sender) >= amountInBaseUnit, "Insufficient token balance");

        // Burn the tokens
        _burn(msg.sender, amountInBaseUnit);

        // Calculate the amount to withdraw and log the withdrawal
        uint256 remainingAmount = amountInBaseUnit;
        uint256 withdrawalAmount;
        string memory bankId;

        while (remainingAmount > 0 && deposits[msg.sender].length > 0) {
            BankDeposit storage lastDeposit = deposits[msg.sender][deposits[msg.sender].length - 1];
            if (lastDeposit.amount <= remainingAmount) {
                withdrawalAmount = lastDeposit.amount;
                bankId = lastDeposit.bankId;
                remainingAmount -= lastDeposit.amount;
                deposits[msg.sender].pop(); // Remove the last element
            } else {
                withdrawalAmount = remainingAmount;
                lastDeposit.amount -= remainingAmount;
                remainingAmount = 0;
                bankId = lastDeposit.bankId;
            }
        }
    }

    /* Node reward function */
    function rewardNode(address node) public onlyRole(NODE_MAINTAINER_ROLE) {
        require(block.timestamp >= nodes[node].lastRewardTime + REWARD_INTERVAL, "Reward interval has not passed");
        
        // Mint the reward tokens to the node
        _mint(node, NODE_REWARD);

        // Update the last reward time
        nodes[node].lastRewardTime = block.timestamp;
    }

    /* Block miner reward function */
    function rewardBlockMiner() public {
        address miner = block.coinbase;
        require(miner != address(0), "Invalid miner address");

        // Define a fixed reward amount for the miner
        uint256 minerReward = 10 * 10 ** decimals(); // 블록 채굴시 10개의 보상을 지급

        // Mint the reward tokens to the block miner
        _mint(miner, minerReward);
    }

    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }


    /* Transfer function with additional checks */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance for transfer");

        _transfer(msg.sender, to, amount);
        return true;
    }

    /* TransferFrom function with additional checks */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balanceOf(from) >= amount, "Insufficient balance for transfer");

        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        return true;
    }

}
