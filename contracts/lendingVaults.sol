// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.03.30

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/iDepositOrLoanCoin.sol";
import "./interfaces/iLendingManager.sol";
import "./interfaces/iDecimals.sol";

contract lendingVaults  {
    address public lendingManager;

    address public setter;
    address newsetter;
    address public rebalancer;

    using SafeERC20 for IERC20;

    constructor() {
        setter = msg.sender;
    }

    //----------------------------modifier ----------------------------

    modifier onlySetter() {
        require(msg.sender == setter, 'Lending Manager: Only Setter Use');
        _;
    }
    modifier onlyManager() {
        require(msg.sender == lendingManager, 'Lending Manager: Only Setter Use');
        _;
    }
    modifier onlyRebalancer() {
        require(msg.sender == rebalancer, 'Lending Manager: Only Rebalancer Use');
        _;
    }

    //----------------------------        ----------------------------
    function transferSetter(address _set) external onlySetter{
        require(_set != address(0),"Deposit Or Loan Coin: New setter cannot be zero address");
        require(_set != setter,"Lending Manager: Cannot transfer to current setter");
        newsetter = _set;
    }
    function acceptSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'Lending Manager: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    function setManager(address _manager) external onlySetter{
        lendingManager = _manager;
    }
    function setRebalancer(address _rebalancer) external onlySetter{
        rebalancer = _rebalancer;
    }
    // H-3 Mitigation: excessDisposal sweeps donated/excess tokens that sit outside
    // supply-based accounting. Rebalancer should call this periodically to prevent
    // balance divergence from being exploitable.
    function excessDisposal(address token) public onlyRebalancer(){
        address[2] memory pair = iLendingManager(lendingManager).assetsDepositAndLendAddrs(token);
        uint amountD18 = iDepositOrLoanCoin(pair[0]).totalSupply();
        uint amountL18 = iDepositOrLoanCoin(pair[1]).totalSupply();

        uint netNorm18 = amountD18 - amountL18;
        uint d = iDecimals(token).decimals();
        uint balRaw = IERC20(token).balanceOf(address(this));
        uint balNorm18 = (balRaw * 1 ether) / (10 ** d);

        require(balNorm18 > netNorm18,"Lending Manager: Cant Do Excess Disposal, asset not enough!");
        uint exNorm18 = balNorm18 - netNorm18;
        uint exRaw = (exNorm18 * (10 ** d)) / 1 ether;
        IERC20(token).safeTransfer(msg.sender, exRaw);
    }

    function vaultsERC20Approve(address ERC20Addr,uint amount) external onlyManager{
        IERC20(ERC20Addr).safeIncreaseAllowance(lendingManager,amount);
    }

    function transferNativeToken(address _to) external onlySetter{
        if(address(this).balance>0){
            address payable receiver = payable(_to); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: 0g Transfer Failed");
        }
    }

    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}