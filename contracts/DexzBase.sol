pragma solidity ^0.5.0;

import "SafeMath.sol";
import "ERC20Interface.sol";
import "Owned.sol";

// ----------------------------------------------------------------------------
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase is Owned {
    using SafeMath for uint;

    enum TokenWhitelistStatus {
        NONE,
        BLACKLIST,
        WHITELIST
    }

    uint constant public TENPOW18 = uint(10)**18;

    uint public deploymentBlockNumber;
    uint public takerFee = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    mapping(address => TokenWhitelistStatus) public tokenWhitelist;

    // Data => block.number when first seen
    mapping(address => uint) tokens;
    mapping(address => uint) accounts;
    mapping(bytes32 => uint) pairs;

    event TokenWhitelistUpdated(address indexed token, uint oldStatus, uint newStatus);
    event TakerFeeUpdated(uint oldTakerFee, uint newTakerFee);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);

    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);


    constructor(address _feeAccount) public {
        initOwned(msg.sender);
        deploymentBlockNumber = block.number;
        feeAccount = _feeAccount;
        addAccount(address(this));
    }

    function getTokenBlockNumber(address token) public view returns (uint _blockNumber) {
        _blockNumber = tokens[token];
    }
    function getAccountBlockNumber(address account) public view returns (uint _blockNumber) {
        _blockNumber = accounts[account];
    }
    function getPairBlockNumber(bytes32 _pairKey) public view returns (uint _blockNumber) {
        _blockNumber = pairs[_pairKey];
    }


    function whitelistToken(address token, uint status) public onlyOwner {
        emit TokenWhitelistUpdated(token, uint(tokenWhitelist[token]), status);
        tokenWhitelist[token] = TokenWhitelistStatus(status);
    }
    function setTakerFee(uint _takerFee) public onlyOwner {
        emit TakerFeeUpdated(takerFee, _takerFee);
        takerFee = _takerFee;
    }
    function setFeeAccount(address _feeAccount) public onlyOwner {
        emit FeeAccountUpdated(feeAccount, _feeAccount);
        feeAccount = _feeAccount;
    }

    function addToken(address token) internal {
        if (tokens[token] == 0) {
            tokens[token] = block.number;
            emit TokenAdded(token);
        }
    }
    function addAccount(address account) internal {
        if (accounts[account] == 0) {
            accounts[account] = block.number;
            emit AccountAdded(account);
        }
    }
    function addPair(bytes32 _pairKey, address baseToken, address quoteToken) internal {
        if (pairs[_pairKey] == 0) {
            pairs[_pairKey] = block.number;
            emit PairAdded(_pairKey, baseToken, quoteToken);
        }
    }


    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        _tokens = ERC20Interface(token).allowance(wallet, address(this));
        _tokens = _tokens.min(ERC20Interface(token).balanceOf(wallet));
    }
    function transferFrom(address token, address from, address to, uint _tokens) internal {
        TokenWhitelistStatus whitelistStatus = tokenWhitelist[token];
        // Difference in gas for 2 x maker fills - wl 293405, no wl 326,112
        if (whitelistStatus == TokenWhitelistStatus.WHITELIST) {
            require(ERC20Interface(token).transferFrom(from, to, _tokens));
        } else if (whitelistStatus == TokenWhitelistStatus.NONE) {
            uint balanceToBefore = ERC20Interface(token).balanceOf(to);
            require(ERC20Interface(token).transferFrom(from, to, _tokens));
            uint balanceToAfter = ERC20Interface(token).balanceOf(to);
            require(balanceToBefore.add(_tokens) == balanceToAfter);
        } else {
            revert();
        }
    }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------
