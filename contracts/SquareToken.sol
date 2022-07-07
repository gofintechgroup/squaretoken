// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

interface ITokenSeller {
    function sellAvailability(address _adr) external view returns (uint256);
}

contract SquareToken is ERC20, ERC20Capped, ERC20Burnable {
    string public constant NAME = "Square Token";
    string public constant SYMBOL = "SQUA";
    uint256 public constant CAP = 5000000 * 10**18;

    ITokenSeller public tokenSeller;

    constructor(address _tokenSeller) ERC20(NAME, SYMBOL) ERC20Capped(CAP) {
        // Mint total cap tokens to the owner
        require(_tokenSeller != address(0), "TokenSeller cannot be zero address");
        tokenSeller = ITokenSeller(_tokenSeller);
        _mint(msg.sender, CAP);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Capped) {
        uint256 sellingAvailability = tokenSeller.sellAvailability(from);
        require(sellingAvailability < block.timestamp || sellingAvailability == 0, "cannot sell until period is over");
        super._beforeTokenTransfer(from, to, amount);
    }
}
