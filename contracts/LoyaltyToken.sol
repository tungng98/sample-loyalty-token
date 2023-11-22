// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "./VRC25Permit.sol";

contract LoyaltyToken is VRC25Permit {
    uint256 internal _currentCycle;
    mapping(address => bool) _nonExpirableAddress;
    mapping(uint256 => mapping(address => uint256)) internal _expirableBalances;
    mapping(uint256 => uint256) internal _expirableTotalSupply;

    constructor() public VRC25("LoyaltyToken", "LTT", 18) {}

    /**
     * @notice Returns current cycle number
     */
    function currentCycle() public view returns (uint256) {
        return _currentCycle;
    }

    /**
     * @notice Returns the amount of tokens in existence.
     */
    function totalSupply() public virtual view override returns (uint256) {
        return _totalSupply + _expirableTotalSupply[currentCycle()];
    }

    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @param owner The address to query the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public virtual view override returns (uint256) {
        if(_nonExpirableAddress[owner]) {
            return _balances[owner];
        }
        return _expirableBalances[currentCycle()][owner];
    }

    /**
     * @notice Advanced to new cycle. All expirable balances will be lost and can't be recovered
     */
    function advanceCycle() external onlyOwner() {
        _currentCycle = _currentCycle.add(1);
    }

    /**
     * @notice Set an address to
     * @param owner the address to be updated
     * @param nonExpirable where balance will be keep if cycle is advanced
     */
    function switchBalance(address owner, bool nonExpirable) external onlyOwner() {
        if(_nonExpirableAddress[owner] == nonExpirable) {
            return;
        }
        if(_nonExpirableAddress[owner]) {
            _nonExpirableAddress[owner] = false;
            _expirableBalances[currentCycle()][owner] = _balances[owner];
            _balances[owner] = 0;
        } else {
            _nonExpirableAddress[owner] = true;
            _balances[owner] = _expirableBalances[currentCycle()][owner];
            _expirableBalances[currentCycle()][owner] = 0;
        }
    }

    /**
     * @notice Calculate fee needed to transfer `amount` of tokens.
     */
    function _estimateFee(uint256 value) internal view virtual override returns (uint256) {
        return _minFee;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param amount The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "VRC25: transfer from the zero address");
        require(to != address(0), "VRC25: transfer to the zero address");
        if(_nonExpirableAddress[from]) {
            require(amount <= _balances[from], "VRC25: insuffient balance");
            _balances[from] = _balances[from].sub(amount);
        } else {
            require(amount <= _expirableBalances[_currentCycle][from], "VRC25: insuffient balance");
            _expirableBalances[_currentCycle][from] = _expirableBalances[_currentCycle][from].sub(amount);
        }
        if(_nonExpirableAddress[to]) {
            _balances[to] = _balances[to].add(amount);
        } else {
            _expirableBalances[_currentCycle][to] = _expirableBalances[_currentCycle][to].add(amount);
        }
        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal function that burns an amount of the token
     * This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param from The account that token amount will be deducted.
     * @param amount The amount that will be burned.
     */
    function _burn(address from, uint256 amount) internal override {
        require(from != address(0), "VRC25: burn from the zero address");
        require(amount <= _balances[from], "VRC25: insuffient balance");
        if(_nonExpirableAddress[from]) {
            _totalSupply = _totalSupply.sub(amount);
            _balances[from] = _balances[from].sub(amount);
        } else {
            _expirableTotalSupply[currentCycle()] = _expirableTotalSupply[currentCycle()].sub(amount);
            _expirableBalances[currentCycle()][from] = _expirableBalances[currentCycle()][from].sub(amount);
        }
        emit Transfer(from, address(0), amount);
    }
}
