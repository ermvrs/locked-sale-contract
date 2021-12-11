pragma solidity >=0.8.10;

import "./Ownable.sol";
import "./IBEP20.sol";
import "./SafeBEP20.sol";
import "./IPancakeRouter01.sol";

contract LockedSale is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct Claim {
        uint256 amount;
        uint256 claimBlock;
        bool claimed;
    }

    uint256 saleBP = 1000; // sale base point 100 -> 1%
    uint256 minAmount = 0.01 ether;
    bool saleActive = true;
    uint256 claimTime = 1 hours;

    IBEP20 public token; // token for sale
    IPancakeRouter01 public router;
    address public receiver; // sale funds go to.
    // wbnb , busd
    mapping(address => bool) whiteListedTokens;
    mapping(address => Claim[]) claimList;

    constructor(IBEP20 _token, IPancakeRouter01 _router, address _recv) {
        token = _token;
        router = _router;
        receiver = _recv;
    }

    function buyToken(uint256 _amount, IBEP20 _spendingToken) public onlySaleActive {
        require(msg.sender != address(0) ,"Sender address zero.");
        require(whiteListedTokens[address(_spendingToken)] == true, "This token is not whitelisted.");
        uint256 contractBalance = getContractBalance();
        // require(_amount <= contractBalance, "Requested amount is too much.");
        uint256 currentAmount = getAmountOut(_spendingToken, _amount);
        uint256 saleAddition = currentAmount.mul(saleBP).div(10000);
        uint256 totalTokenAmount = currentAmount.add(saleAddition);
        require(totalTokenAmount >= minAmount, "Total Token amount too low.");
        require(totalTokenAmount <= contractBalance, "Requested amount is too much.");
        _spendingToken.safeTransferFrom(msg.sender, receiver, _amount);
        Claim[] storage claims = claimList[msg.sender];
        claims.push(Claim({
            amount : totalTokenAmount,
            claimBlock : block.timestamp.add(claimTime),
            claimed : false
        }));
        //claimList[msg.sender].push(});
        //token.safeTransfer(msg.sender, totalTokenAmount);

        emit TokenBought(_spendingToken,_amount,totalTokenAmount);
    }


    // _cid => claim id, claim index in array
    function claimTokens(uint64 _cid) public {
        require(msg.sender != address(0), "Sender address zero.");
        Claim memory claim = claimList[msg.sender][_cid];
        require(claim.claimed == false, "Already claimed");
        uint256 currBlock = block.timestamp;
        require(currBlock >= claim.claimBlock, "You have to wait.");
        uint256 amount = claim.amount;
        delete claimList[msg.sender][_cid];
        // eğer yukarıdaki çalışmazsa
        // claimList[msg.sender][_cid].claimed = true;
        token.safeTransfer(msg.sender, amount);

        emit TokensClaimed(amount);
    }

    // internal functions

    function pathMaker(IBEP20 _spendingToken) internal view returns(address[] memory) {
        address[] memory path;
        path = new address[](2);
        path[0] = address(_spendingToken);
        path[1] = address(token);
        return path;
    }

    // view functions

    function getUsersClaims() public view returns(Claim[] memory) {
        require(msg.sender != address(0), "Address zero.");

        Claim[] memory claims = claimList[msg.sender];
        return claims;
    }

    function getContractBalance() public view returns(uint256) {
        uint256 balance = token.balanceOf(address(this));
        return balance;
    }

    function getAmountOut(IBEP20 _spendingToken, uint256 _amount) public view returns(uint256) {
        address[] memory path = pathMaker(_spendingToken);
        uint256[] memory amounts = router.getAmountsOut(_amount, path);
        return amounts[1];
    }

    function getTokensOut(IBEP20 _spendingToken, uint256 _amount) public view returns(uint256) {
        address[] memory path = pathMaker(_spendingToken);
        uint256[] memory amounts = router.getAmountsOut(_amount, path);
        uint256 saleAddition = amounts[1].mul(saleBP).div(10000);
        uint256 totalTokenAmount = amounts[1].add(saleAddition);
        return totalTokenAmount;
    }


    // owner functions

    function setSaleDiscount(uint256 _sale) public onlyOwner {
        require(_sale < 10000, "Sale is too much");
        saleBP = _sale;

        emit SaleDiscountChanged(_sale);
    }

    function setSpendingTokenWhiteListed(IBEP20 _token) public onlyOwner {
        if(whiteListedTokens[address(_token)]) {
            return;
        }

        whiteListedTokens[address(_token)] = true;
    }

    function toggleSaleStatus() public onlyOwner {
        saleActive = !saleActive;
    }

    function setClaimTime(uint256 _time) public onlyOwner {
        claimTime = _time;

        emit ClaimTimeChanged(_time);
    }

    function setMinAmount(uint256 _amount) public onlyOwner {
        minAmount = _amount;

        emit MinAmountChanged(_amount);
    }

    function setReceiverAddress(address _recv) public onlyOwner {
        receiver = _recv;

        emit ReceiverAddressChanged(_recv);
    }

    // modifiers

    modifier onlySaleActive {
        require(saleActive, "Sale is not active.");
        _;
    }

    event SaleDiscountChanged(uint256 discount);
    event ClaimTimeChanged(uint256 time);
    event MinAmountChanged(uint256 amount);
    event ReceiverAddressChanged(address receiver);
    event TokenBought(IBEP20 _spendingToken, uint256 paidAmount, uint256 boughtAmount);
    event TokensClaimed(uint256 amount);
}