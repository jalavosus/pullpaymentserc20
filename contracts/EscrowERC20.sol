// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Escrow} from "@openzeppelin/contracts/utils/escrow/Escrow.sol";

/**
 * EscrowERC20 is {Escrow} but it also supports ERC20/BEP20/whatever tokens.
 */
contract EscrowERC20 is Escrow {
    using Address for address payable;

    event ERC20Deposited(
        address indexed payee,
        IERC20 indexed token,
        uint256 amount
    );

    event ERC20Withdrawn(
        address indexed payee,
        IERC20 indexed token,
        uint256 amount
    );

    mapping(address => mapping(IERC20 => uint256)) private _erc20Deposits;

    constructor() Escrow() {}

    function depositsOf(address payee, IERC20 token)
        public
        view
        returns (uint256)
    {
        return _payeeBalance(payee, token);
    }

    /**
     * @dev Stores the sent token amount as credit to be withdrawn.
     * @param payee The destination address of the funds.
     * @param token IERC20 token being deposited
     * @param amount amount of {token} being deposited
     *
     * Emits a {ERC20Deposited} event.
     */
    function deposit(address payee, IERC20 token, uint256 amount)
        public
        onlyOwner
    {
        // Shove requires in public function so that
        // the error messages get bubbled to [x]scan explorers and
        // ABI clients and such.
        //
        // Look man, I'm used to working with Solidity v0.6.x and that
        // shit was _awful_ about bubbling error messages and events from internal functions.
        require(
            token.balanceOf(msg.sender) >= amount,
            "sender balance too low"
        );

        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "allowance too low"
        );

        _depositERC20(payee, token, amount);

        // Emit event here and not in internal function
        // so that it always shows on things like Etherscan.
        emit ERC20Deposited(payee, token, amount);
    }

    function _depositERC20(address payee, IERC20 token, uint256 amount)
        internal
        onlyOwner
    {
        token.transferFrom(msg.sender, address(this), amount);
        _erc20Deposits[payee][token] += amount;
    }

    /**
     * @dev Withdraw accumulated token balance for a payee, forwarding all gas to the
     * recipient.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param payee The address whose funds will be withdrawn and transferred to.
     * @param token IERC20 token which will be withdrawn
     *
     * Emits a {ERC20Withdrawn} event.
     */
    function withdraw(address payee, IERC20 token)
        public
    {
        (uint256 _amount, bool _withdrawn) = _withdrawERC20(payee, token);

        require(_withdrawn, "no tokens to withdraw for address token combo");

        // Emit event here and not in internal function
        // so that it always shows on things like Etherscan.
        emit ERC20Withdrawn(payee, token, _amount);
    }

    /**
     * @dev The fun heavy lifting behind {withdraw}. Returns an uint256 (can be 0) and
     * a bool corresponding to whether any coin has been moved.
     *
     * @param payee The address whose funds will be withdrawn and transferred to.
     * @param token IERC20 token which will be withdrawn
     */
    function _withdrawERC20(address payee, IERC20 token)
        internal
        returns (uint256, bool)
    {
        uint256 amount = _payeeBalance(payee, token);
        if (amount > 0) {
            token.transfer(payee, amount);
            _erc20Deposits[payee][token] = 0;
            return (amount, true);
        }

        return (amount, false);
    }

    function _payeeBalance(address payee, IERC20 token)
        internal
        view
        returns (uint256)
    {
        return _erc20Deposits[payee][token];
    }
}
