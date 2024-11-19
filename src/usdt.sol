//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts@v4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@v4.9.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@v4.9.0/security/Pausable.sol";

// error NotController(address _address);

contract USDT is Ownable, ERC20, Pausable {
    mapping(address => bool) public isBlackListed;
    mapping(address => bool) public controllers;

    // Global Variable
    uint256 private _totalSupply;

    string private _symbol;
    string private _name;
    address public VNDTController;
    address public receiverAddress;

    // Event
    event DestroyedBlackFunds(address _blackListedUser, uint _balance);
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);
    event MintByController(
        address _controller,
        address _recipient,
        uint _amount
    );  

    // TODO set address receiver
    constructor(
    ) ERC20("Meta Dollar Reward", "USDMR") payable {
        controllers[msg.sender] = true;
        _mint(owner(), 1000000000 * 10 ** 18);
    }

    modifier onlyController() {
        require(controllers[msg.sender], "You're not the Controller");
        _;
    }
    
    function setReceiverAddress(address _address) external onlyOwner {
        receiverAddress = _address;
    }
    
    function editController(
        address _controller,
        bool _status
    ) external onlyOwner returns (bool) {
        controllers[_controller] = _status;
        return _status;
    }

    function Pause() external onlyOwner {
        _pause();
    }

    function UnPause() external onlyOwner {
        _unpause();
    }

    function transfer(
        address to,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        bool success = super.transferFrom(from, to, amount);
        return success;
    }

    function burnByOwner(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function addBlackList(address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function destroyBlackFunds(address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser], "Not in blacklist");
        uint dirtyFunds = balanceOf(_blackListedUser);
        _burn(_blackListedUser,dirtyFunds);
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    function mintToAddress(
        address recipient,
        uint256 amount
    ) public onlyController returns (bool) {
        _mint(recipient, amount);
        return true;
    }

    function mintByController(
        address recipient,
        uint amount
    ) external onlyController returns (bool) {
        _mint(recipient, amount);
        emit MintByController(msg.sender, recipient, amount);
        return true;
    }

    event Commit(address user, uint amount, address commitAddress);
    function CommitToMainnet(uint amount) external returns(address commitAddress){
        // require(balanceOf(msg.sender) >= amount, 'MetaNode: Invalid Balance');
        // burn(amount);
        // commitAddress = create(msg.sender,amount);
        // emit Commit(msg.sender, amount,commitAddress);
        // return commitAddress;
    }

    function ApproveByInterface(
        address caller,
        address spender,
        uint256 amount
    ) external onlyController returns (bool) {
        _approve(caller, spender, amount);
        return true;
    }
}