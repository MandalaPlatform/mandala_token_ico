pragma solidity ^0.4.21;

import './SafeMath.sol';
import './Ownable.sol';
import './MandalaToken.sol';


contract MandalaTokenSale is  Ownable {

    using SafeMath for uint256;

    uint256 public   TOKEN_PRICE_D = 7288;             // Tokens per ether. Initial value

    uint256 constant public   MIN_CONTRIBUTION_WEI = 100000000000000000;             // Minimum contribution in wei

    uint constant PHASES_COUNT = 4;                                          // Count of phases ICO (Pre-sale and ICO)

    uint256 constant public AVAILABLE_FOR_SALE = 260000000 * (10**18);

    uint256 constant public AVAILABLE_FOR_FOUNDERS = 80000000 * (10**18);
    uint256 constant public AVAILABLE_FOR_RESERVE = 40000000 * (10**18);
    uint256 constant public AVAILABLE_FOR_BOUNTY = 20000000 * (10**18);

    address public FOUNDERS_WALLET = 0x822bcaeb803335d0c528ef37c27167a823c2a0440;
    address public RESERVE_WALLET = 0x22934b6de6301d30a92ab6c885d2cbeb4e8003d6;
    address public BOUNTY_WALLET = 0xd18d34edea90d8c71e56cc7529f30fa257782923;

    uint public BONUS_MULTIPLIER = 0;

    bool public IS_FINALIZED = false;
    string public PHASE;

    mapping(uint256 => PhaseParams) public  phases;
    MandalaToken public token;


    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
    event FundsForwarded(address addr);

    struct PhaseParams {
        string NAME;
        uint BONUS_MULTIPLIER;      // Bonus percents
        bool IS_STARTED;
        bool IS_FINISHED;
    }

    function isValidAddress(address _address) returns (bool){
        return (_address != 0x0 && _address != address(0) && _address != 0 && _address != address(this));
    }

    modifier validAddress(address _address) {
        require(isValidAddress(_address));
        _;
    }

    function MandalaTokenSale()
    {
        owner = msg.sender;

        var prePhase = PhaseParams({
            NAME: "Presale",
            BONUS_MULTIPLIER : 25,
            IS_STARTED : false,
            IS_FINISHED : false
            });

        var secondPhase = PhaseParams({
            NAME :"Phase 2",
            BONUS_MULTIPLIER : 10,
            IS_STARTED : false,
            IS_FINISHED : false
            });


        var thirdPhase = PhaseParams({
            NAME :"Phase 3",
            BONUS_MULTIPLIER : 5,
            IS_STARTED : false,
            IS_FINISHED : false
            });


        var finalPhase = PhaseParams({
            NAME :"Phase 4",
            BONUS_MULTIPLIER : 0,
            IS_STARTED : false,
            IS_FINISHED : false
            });

        phases[0] = prePhase;
        phases[1] = secondPhase;
        phases[2] = thirdPhase;
        phases[3] = finalPhase;

    }

    // Fallback function, being executed when an investor sends Ethereum
    
    function buyTokens(address _beneficiary) public payable {
        require(msg.sender == _beneficiary);
        uint256 wei_value = msg.value;
        require(wei_value >= MIN_CONTRIBUTION_WEI);
        _buyTokens(_beneficiary, wei_value);
    }

    function() external payable {
        buyTokens(msg.sender);
    }

    // Function to process non-ethereum payments
    function offchainPurchase(address beneficiar, uint256 WEIequity) public onlyOwner {
        _buyTokens(beneficiar, WEIequity);
    }

    function setBonusMultiplier(uint multiplier){
        BONUS_MULTIPLIER = multiplier;
    }

    // Function for burning tokens from specified address
    function burnTokens(address victim, uint256 amount) public onlyOwner {
        require(!IS_FINALIZED);

        token.burnFrom(amount, victim);
    }

    function mintTokens(address beneficiar, uint256 amount) onlyOwner{
        _mintTokens(beneficiar, amount);
    }

    function _mintTokens(address beneficiar, uint256 amount) internal{
        require((token.totalSupply() + amount) <= AVAILABLE_FOR_SALE);
        require(token.mint(beneficiar, amount));
    }

    // Function of token purchase
    function _buyTokens(address beneficiar, uint256 amount) internal{

        require(!IS_FINALIZED);
        require(!phases[getCurrentPhaseIndex()].IS_FINISHED);

        uint256 tokens = amount.mul(TOKEN_PRICE_D);

        uint256 phase_bonus = tokens.div(100).mul(BONUS_MULTIPLIER);

        uint256 tokens_to_mint = tokens+ phase_bonus;

        _mintTokens(beneficiar, tokens_to_mint);

        TokenPurchase(beneficiar, tokens_to_mint, tokens);
    }

    // Function for transferring Funds
    function forwardFunds(address beneficiar) public onlyOwner {
        beneficiar.transfer(this.balance);
        FundsForwarded(beneficiar);
    }

    function startTokenSale() public onlyOwner returns(bool){
        require(isValidAddress(FOUNDERS_WALLET));
        require(isValidAddress(RESERVE_WALLET));
        require(isValidAddress(BOUNTY_WALLET));

        phases[0].IS_STARTED = true;
        PHASE = phases[0].NAME;
        setBonusMultiplier(phases[0].BONUS_MULTIPLIER);

        return true;
    }

    function setFoundersWallet(address addr) validAddress(addr) onlyOwner{
        FOUNDERS_WALLET = addr;
    }

    function setReserveWallet(address addr) validAddress(addr) onlyOwner{
        RESERVE_WALLET = addr;
    }

    function setBountyWallet(address addr) validAddress(addr) onlyOwner{
        BOUNTY_WALLET = addr;
    }


    function finalizeTokenSale() public onlyOwner{
        require(!IS_FINALIZED);

        require(token.mint(FOUNDERS_WALLET,AVAILABLE_FOR_FOUNDERS));
        require(token.mint(RESERVE_WALLET,AVAILABLE_FOR_RESERVE));
        require(token.mint(BOUNTY_WALLET,AVAILABLE_FOR_BOUNTY));

        require(token.lock(FOUNDERS_WALLET, now + 15768000, AVAILABLE_FOR_FOUNDERS));
        require(token.lock(FOUNDERS_WALLET, now + 31536000, AVAILABLE_FOR_FOUNDERS.div(2)));


        IS_FINALIZED = true;
        token.finishMinting();
        token.resumeTransfers();
    }


    function startNextPhase() public onlyOwner{
        uint i = getCurrentPhaseIndex();
        require((i+1) <= PHASES_COUNT);
        require(phases[i].IS_FINISHED);
        setBonusMultiplier(phases[i+1].BONUS_MULTIPLIER);
        phases[i+1].IS_STARTED = true;
        PHASE = phases[i+1].NAME;
    }


    function finishCurrentPhase() public onlyOwner{
        uint i = getCurrentPhaseIndex();
        phases[i].IS_FINISHED = true;

        if ((i+1) == PHASES_COUNT){
            finalizeTokenSale();
        }
    }

    // Getting current phase index
    function getCurrentPhaseIndex() public view returns (uint){
        uint current_phase = 0;
        for (uint i = 0; i < PHASES_COUNT; i++)
        {
            if (phases[i].IS_STARTED) {
                current_phase = i;
            }

        }
        return current_phase;
    }

    // Function for ansferring the ownership of Token contract
    function transferTokenOwnership(address newOwner) public onlyOwner {
        token.transferOwnership(newOwner);
    }

    function setToken(address addr) onlyOwner {
        token =  MandalaToken(addr);

    }

}