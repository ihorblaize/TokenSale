// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Positive Even Number Setter -- the contract which sets a value of the positive even number.
 *
 * @dev This contract includes the following functionality:
 *  - Setting of the positive even number by the owner.
 *  - Getting of a value of the set number.
 */
contract TokenSale is Ownable, AccessControl {

}