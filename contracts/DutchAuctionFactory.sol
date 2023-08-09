// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC721 {
    function safeTransferFrom(address from, address to, uint tokenId) external;

    function transferFrom(address, address, uint) external;
}

contract DutchAuction {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address highestBidder, uint amount);

    IERC721 public nft;
    uint public nftId;

    address payable public seller;
    uint public startPrice;
    uint public endPrice;
    uint public duration;
    uint public startTime;
    bool public started;
    bool public ended;

    string public title;
    string public description;

    address payable public highestBidder;
    uint public highestBid;

    constructor(
        address _nft,
        uint _nftId,
        uint _startPrice,
        uint _endPrice,
        uint _duration, 
        string memory _title,
        string memory _description,
        address sender
    ) {
        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(sender);
        startPrice = _startPrice;
        endPrice = _endPrice;
        duration = _duration;
        title = _title;
        description = _description;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        startTime = block.timestamp;

        emit Start();
    }

    function getCurrentPrice() public view returns (uint) {
        if (block.timestamp >= startTime + duration) {
            return endPrice;
        } else {
            uint elapsedTime = block.timestamp - startTime;
            uint priceRange = startPrice - endPrice;
            return startPrice - (elapsedTime * priceRange) / duration;
        }
    }

    function bid() external payable {
        require(started, "not started");
        require(!ended, "ended");
        require(block.timestamp < startTime + duration, "auction expired");

        uint currentPrice = getCurrentPrice();
        require(msg.value >= currentPrice, "value < current price");

        if (highestBidder != address(0)) {
            highestBidder.transfer(highestBid);
        }

        highestBidder = payable(msg.sender);
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        require(ended, "not ended");
        require(msg.sender != highestBidder, "highest bidder cannot withdraw");

        uint bal = highestBid;
        highestBid = 0;
        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(!ended, "ended");
        require(block.timestamp >= startTime + duration, "auction not ended");

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

contract DutchAuctionFactory {
    address[] public auctions;

    function createAuction(
        address _nft,
        uint _nftId,
        uint _startPrice,
        uint _endPrice,
        uint _duration,
        string memory _title,
        string memory _description
    ) external returns (address) {
        DutchAuction newAuction = new DutchAuction(
            _nft,
            _nftId,
            _startPrice,
            _endPrice,
            _duration,
            _title,
            _description,
            msg.sender
        );
        auctions.push(address(newAuction));
        return address(newAuction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }
}