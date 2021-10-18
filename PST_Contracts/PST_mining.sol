// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IDRC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint amount) external returns (bool);

    function burn(uint amount_) external;

    function burnAmount() external returns (uint);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract IDD_Mining is Ownable {
    using SafeERC20 for IDRC20;
    IDRC20 public IDD;
    IDRC20 public LP;
    uint public constant Acc = 1e10;
    uint public constant daliyOut = 216328 * 1e15;
    uint public constant rate = daliyOut / 1 days / 2;
    uint public effUser;
    uint public totalAmount;
    uint public TVL;
    uint public debt;
    uint public lastTime;
    bool public status;
    address public pair;
    address public U;
    address public Token;
    uint public startTime;
    uint public totalClaimed;


    event Stake(address indexed sender_, uint indexed amount_);
    event UnStake(address indexed sender_);
    event ClaimReward(address indexed sender_, uint indexed amount_);
    event ClaimDynamic(address indexed sender_, uint indexed amount_);

    struct UserInfo {
        uint stakeAmount;
        address invitor;
        uint debt;
        uint stakeTime;
        uint price;
        uint toClaim;
        uint dynamic;
        uint claimed;
        uint refer;
        uint groupAmount;
        uint dynamicClaimed;
    }

    mapping(address => UserInfo)public userInfo;

    function setStatus(bool com_) public onlyOwner {
        status = com_;

    }

    function setAddress(address IDD_, address LP_, address U_, address Pair_) public onlyOwner {
        IDD = IDRC20(IDD_);
        LP = IDRC20(LP_);
        U = U_;
        Token = IDD_;
        pair = Pair_;
    }

    function coutingDebt() public view returns (uint _debt){
        _debt = TVL > 0 ? rate * (block.timestamp - lastTime) * Acc / TVL + debt : 0;
    }

    function getUserPrice(uint amount_) public view returns (uint price){

        (uint token0,,) = IPancakePair(pair).getReserves();
        price = (amount_ * token0 * 2) / LP.totalSupply();
    }

    function getNow() public view returns (uint out_){

        if (startTime == 0) {
            out_ = 0;
        } else {
            out_ = (block.timestamp - startTime) * rate;
        }

    }

    function getUserLevel(address addr_) public view returns (uint level){
        uint temp = userInfo[addr_].price;
        level = 0;
        if (temp >= 3000 ether) {
            level = 6;
        } else if (temp >= 1000 ether) {
            level = 3;
        } else if (temp >= 500 ether) {
            level = 2;
        } else if (temp >= 100 ether) {
            level = 1;
        }
    }

    function calculetReward(address addr_) view public returns (uint){
        require(userInfo[addr_].stakeAmount > 0, 'no amount');
        // PoolInfo storage pool = poolInfo[poolNum_];
        uint _debt = coutingDebt();
        uint reward = (_debt - userInfo[addr_].debt) * userInfo[addr_].stakeAmount / Acc;
        return reward;
    }

    function checkBrunRate(uint amount_) view public returns (uint){
        if (effUser >= 10000) {
            amount_ = amount_;
        } else if (effUser >= 6000) {
            amount_ = amount_ * 8 / 10;
        } else if (effUser >= 2000) {
            amount_ = amount_ * 6 / 10;
        } else if (effUser < 2000) {
            amount_ = amount_ * 4 / 10;
        }
        if (IDD.balanceOf(address(0)) >= 60000 ether) {
            amount_ = amount_ * 3 / 10;
        } else if (IDD.balanceOf(address(0)) >= 20000 ether) {
            amount_ = amount_ / 2;
        }
        return amount_;
    }

    function claimReward() public {
        require(userInfo[msg.sender].stakeAmount > 0, 'no amount');
        uint rew = calculetReward(msg.sender);
        uint newRew = checkBrunRate(rew);
        IDD.transfer(msg.sender, newRew + userInfo[msg.sender].toClaim);
        totalClaimed += newRew;
        userInfo[msg.sender].debt = coutingDebt();
        userInfo[msg.sender].claimed += newRew + userInfo[msg.sender].toClaim;
        userInfo[msg.sender].toClaim = 0;
        uint tempBurn = newRew;
        address temp = userInfo[msg.sender].invitor;
        uint tempRew;
        uint level;
        for (uint i = 0; i < 25; i++) {
            if (temp == address(0) || temp == address(this)) {
                break;
            }
            level = getUserLevel(temp);
            if (i >= 10) {

                if (level >= 6) {
                    tempRew = newRew * 3 / 100;
                    userInfo[temp].dynamic += tempRew;
                    tempBurn -= tempRew;
                }
            } else if (i >= 9) {
                if (level >= 6) {
                    tempRew = newRew * 5 / 100;
                    userInfo[temp].dynamic += tempRew;
                    tempBurn -= tempRew;
                }
            } else if (i >= 5) {
                if (level >= 3) {
                    tempRew = newRew * 5 / 100;
                    userInfo[temp].dynamic += tempRew;
                    tempBurn -= tempRew;
                }
            } else if (i >= 1) {
                if (level >= 2) {
                    tempRew = newRew * 5 / 100;
                    userInfo[temp].dynamic += tempRew;
                    tempBurn -= tempRew;
                }
            } else if (i >= 0) {
                if (level >= 1) {
                    tempRew = newRew * 5 / 100;
                    userInfo[temp].dynamic += tempRew;
                    tempBurn -= tempRew;
                }
            }
            temp = userInfo[temp].invitor;

        }
        IDD.burn(tempBurn + rew - newRew);
        emit ClaimReward(msg.sender, newRew);
    }

    function stakeLP(uint amount_, address invitor_) public {
        require(amount_ > 0, "wrong amount");
        require(status, 'not open');
        if (TVL == 0) {
            startTime == block.timestamp;
        }

        if (userInfo[msg.sender].invitor == address(0)) {
            require(userInfo[invitor_].invitor != address(0) || invitor_ == address(this), 'wrong invitor');
            userInfo[msg.sender].invitor = invitor_;


        }
        address temp = userInfo[msg.sender].invitor;
        if (userInfo[msg.sender].stakeAmount > 0) {
            for (uint i = 0; i < 25; i++) {
                if (temp == address(0) || temp == address(this)) {
                    break;
                }
                userInfo[temp].groupAmount += amount_;
                temp = userInfo[temp].invitor;
                // userInfo[temp].refer +=1;
            }
            uint rew = calculetReward(msg.sender);
            userInfo[msg.sender].toClaim += rew;
            TVL += amount_;
            effUser ++;
            uint d = coutingDebt();
            debt = d;
            lastTime = block.timestamp;
            userInfo[msg.sender].debt = d;
            userInfo[msg.sender].stakeAmount += amount_;
            userInfo[msg.sender].price += getUserPrice(amount_);
            // userInfo[msg.sender].level = getUserLevel(msg.sender);
            LP.transferFrom(msg.sender, address(this), amount_);


        } else {

            for (uint i = 0; i < 25; i++) {
                if (temp == address(0) || temp == address(this)) {
                    break;
                }
                userInfo[temp].refer += 1;
                userInfo[temp].groupAmount += amount_;
                temp = userInfo[temp].invitor;
            }
            TVL += amount_;
            effUser ++;
            uint d = coutingDebt();
            debt = d;
            lastTime = block.timestamp;
            userInfo[msg.sender].debt = d;
            userInfo[msg.sender].stakeAmount += amount_;
            userInfo[msg.sender].price += getUserPrice(amount_);
            // userInfo[msg.sender].level = getUserLevel(msg.sender);
            LP.transferFrom(msg.sender, address(this), amount_);

        }
        emit Stake(msg.sender, amount_);
        userInfo[msg.sender].stakeTime = block.timestamp;

    }

    function unStake() external {
        require(userInfo[msg.sender].stakeAmount > 0, 'no amount');
        claimReward();
        TVL -= userInfo[msg.sender].stakeAmount;
        debt = coutingDebt();
        lastTime = block.timestamp;
        LP.transfer(msg.sender, userInfo[msg.sender].stakeAmount);
        address temp = userInfo[msg.sender].invitor;
        for (uint i = 0; i < 25; i++) {
            if (temp == address(0) || temp == address(this)) {
                break;
            }
            userInfo[temp].refer -= 1;
            userInfo[temp].groupAmount -= userInfo[msg.sender].stakeAmount;
            temp = userInfo[temp].invitor;
        }
        userInfo[msg.sender].stakeAmount = 0;
        userInfo[msg.sender].debt = 0;
        userInfo[msg.sender].price = 0;
        effUser --;

        emit UnStake(msg.sender);
    }

    function claimDynamic() external {
        require(userInfo[msg.sender].dynamic > 0);
        uint amount_ = userInfo[msg.sender].dynamic;
        IDD.transfer(msg.sender, amount_);
        userInfo[msg.sender].dynamic = 0;
        userInfo[msg.sender].dynamicClaimed += amount_;
        totalClaimed += amount_;
        emit ClaimDynamic(msg.sender, amount_);
    }

    function safePull(address token_, address wallet, uint amount_) public onlyOwner {
        IERC20(token_).transfer(wallet, amount_);
    }
}