// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TokenSeller is Ownable, AccessControl {
    using SafeMath for uint256;

    address public token;
    uint256 public whitelistQuantity;
    uint256 public sellRate;
    uint256 public MAX_AMOUNT = 500 * 10**18;
    uint16 public MAX_ACCOUNTS = 6000;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public phaseTimestamp;
    uint256 public phaseDuration;
    uint256 public phaseRate;
    uint256 public phasePackage;
    uint256 public phaseSellLock;
    bool public phaseActive;
    

    struct AccountStruct {
        bool whitelisted;
        bool phaseBought;
        uint256 bought;
        uint256 unlockTimestamp;
    }

    mapping(address => AccountStruct) list;

    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not a operator");
        _;
    }

    constructor(
        uint256 _rate,
        address _operator
    ) {
        require(_rate != 0, "_rate is required");
        require(_operator != address(0), "_operator is required");
        sellRate = _rate;
        // Grant the operator role
        _setupRole(OPERATOR_ROLE, _operator);
        // Grant the contract deployer the default admin role:
        // it will be able to grant and revoke any role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    receive() external payable {
        require(phaseActive, "no selling phase active");
        require(list[msg.sender].whitelisted, "account is not whitelisted");
        require(!list[msg.sender].phaseBought, "already bought package");
        require(phaseTimestamp + phaseDuration > block.timestamp, "selling phase ended");

        require(msg.value == sellRate, "must send the exact amount for the package");

        list[msg.sender].phaseBought = true;
        list[msg.sender].unlockTimestamp = phaseTimestamp + phaseDuration + phaseSellLock;
        list[msg.sender].bought += phasePackage;

        require(IERC20(token).transfer(msg.sender, phasePackage), "token transfer fail");
    }

    function setTokenAddress(address _token) public onlyOperator {
        token = _token;
    }

    function withdrawBNB(uint256 amount) external onlyOperator{
        payable(msg.sender).transfer(amount);
    }

    function withdrawToken(uint256 amount) external onlyOperator{
        IERC20(token).transfer(msg.sender, amount);
    }

    function sellAvailability(address _adr) public view returns (uint256){
        return list[_adr].unlockTimestamp;
    }

    function addAddresses(address[] memory _addresses) external onlyOperator {
        require(_addresses.length > 0, "Address list is required");
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (
                !list[_addresses[i]].whitelisted &&
                whitelistQuantity < MAX_ACCOUNTS
            ) {
                list[_addresses[i]].whitelisted = true;
                whitelistQuantity++;
            }
        }
    }

    function removeAddresses(address[] memory _addresses) external onlyOperator {
        require(_addresses.length > 0, "Address list is required");
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (list[_addresses[i]].whitelisted) {
                list[_addresses[i]].whitelisted = false;
                whitelistQuantity--;
            }
        }
    }

    function activatePhase(uint16 _maxAccounts, uint256 _rate, uint256 _phasePackage, uint256 _duration, uint256 _phaseSellLock) 
        public onlyOperator {
        MAX_ACCOUNTS = _maxAccounts;
        phasePackage = _phasePackage * 10**18;
        phaseDuration = _duration;
        sellRate = _rate ;
        phaseTimestamp = block.timestamp;
        phaseSellLock = _phaseSellLock;
        phaseActive = true;
    }

    function extendPhase(uint256 duration) public onlyOperator {
        phaseDuration += duration;
        phaseSellLock += duration;
    }

    function deactivatePhaseSale() public onlyOperator {
        phaseActive = false;        
    }

    function changeSellRate(uint256 newSellRate, uint256 _phasePackage) public onlyOperator {
        sellRate = newSellRate;
        phasePackage = _phasePackage * 10**18;
    }

    function isWhitelisted(address _adr) public view returns (bool) {
        return list[_adr].whitelisted;
    }

    function getDepositAmount() public view returns (uint256) {
        return sellRate;
    }
}
