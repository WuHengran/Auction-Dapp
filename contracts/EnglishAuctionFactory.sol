// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC721 {
    function safeTransferFrom(address from, address to, uint tokenId) external;

    function transferFrom(address, address, uint) external;
}

contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address highestBidder, uint amount);

    IERC721 public nft;
    uint public nftId;

    address payable public seller;
    uint public endAt;
    bool public started;
    bool public ended;

    string public title;
    string public description;

    address public highestBidder;
    uint public highestBid;
    mapping(address => uint) public bids;

    constructor(address _nft, 
        uint _nftId, 
        uint _startingBid, 
        string memory _title, 
        string memory _description,
        address sender
    ) {
        nft = IERC721(_nft);
        nftId = _nftId;
        title = _title;
        description = _description;

        seller = payable(sender);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        endAt = block.timestamp + 60;

        emit Start();
    }
    
    function getSender() external view returns (address) {
        return msg.sender;
    }
    
    function getSeller() external view returns (address) {
        return seller;
    }

    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            seller.transfer(highestBid);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}

contract EnglishAuctionFactory {
    address[] public auctions;
    
    function createAuction(
        address _nft,
        uint _nftId,
        uint _startingBid,
        string memory _title, 
        string memory _description
    ) external returns (address) {
        EnglishAuction newAuction = new EnglishAuction(_nft, _nftId, _startingBid, _title, _description, msg.sender);
        auctions.push(address(newAuction));
        return address(newAuction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }
}