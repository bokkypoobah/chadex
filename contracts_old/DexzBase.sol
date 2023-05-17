pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Owned.sol";

// ----------------------------------------------------------------------------
// DexzBase
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
contract DexzBase is Owned {
    uint constant public TENPOW18 = uint(10)**18;

    uint public deploymentBlockNumber;
    uint public takerFeeInEthers = 5 * 10 ** 16; // 0.05 ETH
    uint public takerFeeInTokens = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

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

    event TakerFeeInEthersUpdated(uint oldTakerFeeInEthers, uint newTakerFeeInEthers);
    event TakerFeeInTokensUpdated(uint oldTakerFeeInTokens, uint newTakerFeeInTokens);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);

    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);


    constructor(address _feeAccount) {
        initOwned(msg.sender);
        deploymentBlockNumber = block.number;
        feeAccount = _feeAccount;
        addAccount(address(this));
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
            require(ERC20(token).totalSupply() > 0);
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
        uint _allowance = ERC20(token).allowance(wallet, address(this));
        uint _balance = ERC20(token).balanceOf(wallet);
        if (_allowance < _balance) {
            return _allowance;
        } else {
            return _balance;
        }
    }
    function transferFrom(address token, address from, address to, uint _tokens) internal {
        // TODO: Remove check?
        uint balanceToBefore = ERC20(token).balanceOf(to);
        require(ERC20(token).transferFrom(from, to, _tokens));
        uint balanceToAfter = ERC20(token).balanceOf(to);
        require(balanceToBefore + _tokens == balanceToAfter);
    }


    // TODO
    // function recoverTokens(address token, uint tokens) public onlyOwner {
    //     if (token == address(0)) {
    //         payable(uint160(owner)).transfer((tokens == 0 ? address(this).balance : tokens));
    //     } else {
    //         ERC20(token).transfer(owner, tokens == 0 ? ERC20(token).balanceOf(address(this)) : tokens);
    //     }
    // }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------
