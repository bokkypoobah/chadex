pragma solidity ^0.5.0;

// ----------------------------------------------------------------------------
// MintableToken = ERC20 + symbol + name + decimals + mint + burn
//
// NOTE: This token contract allows the owner to mint and burn tokens for any
// account, and is used for testing
//
// https://github.com/bokkypoobah/Dexz
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019. The MIT Licence.
// ----------------------------------------------------------------------------

import "../SafeMath.sol";
import "../Owned.sol";
import "../ApproveAndCallFallback.sol";
import "./MintableTokenInterface.sol";


// ----------------------------------------------------------------------------
// MintableToken = ERC20 + symbol + name + decimals + mint + burn
//
// NOTE: This token contract allows the owner to mint and burn tokens for any
// account, and is used for testing
// ----------------------------------------------------------------------------
contract MintableToken is MintableTokenInterface, Owned {
    using SafeMath for uint;

    string _symbol;
    string  _name;
    uint8 _decimals;
    uint _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor(string memory symbol, string memory name, uint8 decimals, address tokenOwner, uint initialSupply) public {
        initOwned(msg.sender);
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        balances[tokenOwner] = initialSupply;
        _totalSupply = initialSupply;
        emit Transfer(address(0), tokenOwner, _totalSupply);
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view returns (uint) {
        return _totalSupply.sub(balances[address(0)]);
    }
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }
    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    function approveAndCall(address spender, uint tokens, bytes memory data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallback(spender).receiveApproval(msg.sender, tokens, address(this), data);
        return true;
    }
    function mint(address tokenOwner, uint tokens) public onlyOwner returns (bool success) {
        balances[tokenOwner] = balances[tokenOwner].add(tokens);
        _totalSupply = _totalSupply.add(tokens);
        emit Transfer(address(0), tokenOwner, tokens);
        return true;
    }
    function burn(address tokenOwner, uint tokens) public onlyOwner returns (bool success) {
        balances[tokenOwner] = balances[tokenOwner].sub(tokens);
        _totalSupply = _totalSupply.sub(tokens);
        emit Transfer(tokenOwner, address(0), tokens);
        return true;
    }
    function () external payable {
        revert();
    }
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
// ----------------------------------------------------------------------------
// End - MintableToken
// ----------------------------------------------------------------------------
