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
    uint public takerFeeInEthers = 5 * 10 ** 16; // 0.05 ETH
    uint public takerFeeInTokens = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    mapping(address => TokenWhitelistStatus) public tokenWhitelist;

    struct PairInfo {
        bytes32 pairKey;
        address baseToken;
        address quoteToken;
    }

    // Data => block.number when first seen
    mapping(address => uint) public tokenBlockNumbers;
    mapping(address => uint) public accountBlockNumbers;
    mapping(bytes32 => uint) public pairBlockNumbers;
    address[] public tokenList;
    address[] public accountList;
    PairInfo[] public pairInfoList;

    event TokenWhitelistUpdated(address indexed token, uint oldStatus, uint newStatus);
    event TakerFeeInEthersUpdated(uint oldTakerFeeInEthers, uint newTakerFeeInEthers);
    event TakerFeeInTokensUpdated(uint oldTakerFeeInTokens, uint newTakerFeeInTokens);
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

    function whitelistToken(address token, uint status) public onlyOwner {
        emit TokenWhitelistUpdated(token, uint(tokenWhitelist[token]), status);
        tokenWhitelist[token] = TokenWhitelistStatus(status);
    }
    function setTakerFeeInEthers(uint _takerFeeInEthers) public onlyOwner {
        emit TakerFeeInEthersUpdated(takerFeeInEthers, _takerFeeInEthers);
        takerFeeInEthers = _takerFeeInEthers;
    }
    function setTakerFeeInTokens(uint _takerFeeInTokens) public onlyOwner {
        emit TakerFeeInTokensUpdated(takerFeeInTokens, _takerFeeInTokens);
        takerFeeInTokens = _takerFeeInTokens;
    }
    function setFeeAccount(address _feeAccount) public onlyOwner {
        emit FeeAccountUpdated(feeAccount, _feeAccount);
        feeAccount = _feeAccount;
    }

    function tokenListLength() public view returns (uint) {
        return tokenList.length;
    }
    function addToken(address token) internal {
        if (tokenBlockNumbers[token] == 0) {
            require(ERC20Interface(token).totalSupply() > 0);
            tokenBlockNumbers[token] = block.number;
            tokenList.push(token);
            emit TokenAdded(token);
        }
    }
    function accountListLength() public view returns (uint) {
        return accountList.length;
    }
    function addAccount(address account) internal {
        if (accountBlockNumbers[account] == 0) {
            accountBlockNumbers[account] = block.number;
            accountList.push(account);
            emit AccountAdded(account);
        }
    }
    function pairInfoListLength() public view returns (uint) {
        return pairInfoList.length;
    }
    function addPair(bytes32 _pairKey, address baseToken, address quoteToken) internal {
        if (pairBlockNumbers[_pairKey] == 0) {
            pairBlockNumbers[_pairKey] = block.number;
            pairInfoList.push(PairInfo(_pairKey, baseToken, quoteToken));
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


    function recoverTokens(address token, uint tokens) public onlyOwner {
        if (token == address(0)) {
            address(uint160(owner)).transfer((tokens == 0 ? address(this).balance : tokens));
        } else {
            ERC20Interface(token).transfer(owner, tokens == 0 ? ERC20Interface(token).balanceOf(address(this)) : tokens);
        }
    }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------
