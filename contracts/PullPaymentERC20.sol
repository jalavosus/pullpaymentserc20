// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {EscrowERC20} from "./EscrowERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PullPayment} from "@openzeppelin/contracts/security/PullPayment.sol";

/**
 * PullPaymentERC20 is {PullPayment} but it supports ERC20/BEP20/whatever tokens.
 * Is it stupid? Maybe.
 * Does it work? No fucking idea.
 * Was it easy to code? Heck yes it was.
 *
 * Oh fuck all of these things appear in the docstring. Whatever.
 */
abstract contract PullPaymentERC20 is PullPayment {
    EscrowERC20 private immutable _escrowERC20;

    constructor() PullPayment() {
        _escrowERC20 = new EscrowERC20();
    }

    /**
     * @dev Withdraw accumulated ERC20 payments, forwarding all gas to the recipient.
     *
     * Note that _any_ account can call this function, not just the `payee`.
     * This means that contracts unaware of the `PullPayment` protocol can still
     * receive funds this way, by having a separate account call
     * {withdrawPayments}.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param payee Whose payments will be withdrawn.
     * @param token Token to withdraw.
     *
     * Causes the `escrow` to emit an {ERC20Withdrawn} event.
     */
    function withdrawPayments(address payee, IERC20 token)
        public
        virtual
    {
        _escrowERC20.withdraw(payee, token);
    }

    /**
     * @dev Returns the ERC20 payments of a specific token owed to an address.
     * @param dest The creditor's address.
     * @param token Token owed.
     */
    function payments(address dest, IERC20 token)
        public
        virtual
        view
        returns (uint256)
    {
        return _escrowERC20.depositsOf(dest, token);
    }

    /**
     * @dev Called by the payer to store the sent token amount as credit to be pulled.
     * Funds sent in this way are stored in an intermediate {EscrowERC20} contract, so
     * there is no danger of them being spent before withdrawal.
     *
     * @param dest The destination address of the funds.
     * @param amount The amount to transfer.
     * @param token The token to transfer.
     *
     * Causes the `escrow` to emit a {ERC20Deposited} event.
     */
    function _asyncTransfer(address dest, IERC20 token, uint256 amount)
        internal
        virtual
    {
        _escrowERC20.deposit(dest, token, amount);
    }
}
