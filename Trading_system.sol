// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FairDataTradingSystem {
    struct Data {
        address owner;
        string ipfsHash;
        uint256 price;
        bool isAvailable;
        bool agreementAccepted;
        uint256 evaluation;
    }

    struct PurchaseRequest {
        address buyer;
        address seller;
        string ipfsHash;
        uint256 price;
        bool isCompleted;
    }

    mapping(address => Data) public dataRecords;
    mapping(address => bool) public allowedSellers;
    mapping(address => PurchaseRequest) public purchaseRequests;
    mapping(address => mapping(address => bool)) public arbitrationRequests;

    event DataForSaleAdded(address indexed sellerAddress, string ipfsHash, uint256 price);
    event PurchaseRequested(address indexed buyer, address indexed seller, string ipfsHash, uint256 price);
    event PurchaseCompleted(address indexed buyer, address indexed seller, string ipfsHash, uint256 price);
    event DataEvaluated(address indexed evaluator, address indexed dataOwner, uint256 evaluation);
    event ArbitrationRequested(address indexed requester, address indexed arbitrator, string ipfsHash);
    event ArbitrationResolved(address indexed requester, address indexed arbitrator, bool isSimilar);

    function addDataForSale(string memory _ipfsHash, uint256 _price) public {
        require(!dataRecords[msg.sender].isAvailable, "Data already exists for this owner");

        Data memory newData = Data({
            owner: msg.sender,
            ipfsHash: _ipfsHash,
            price: _price,
            isAvailable: false,
            agreementAccepted: false,
            evaluation: 0
        });

        dataRecords[msg.sender] = newData;

        emit DataForSaleAdded(msg.sender, _ipfsHash, _price);
    }

    function requestPurchase(address _seller, string memory _ipfsHash, uint256 _price) public payable {
        require(dataRecords[_seller].isAvailable, "Data not available for sale");
        require(allowedSellers[_seller], "Seller not approved");
        require(msg.value == _price, "Incorrect payment amount");

        PurchaseRequest memory newRequest = PurchaseRequest({
            buyer: msg.sender,
            seller: _seller,
            ipfsHash: _ipfsHash,
            price: _price,
            isCompleted: false
        });

        purchaseRequests[msg.sender] = newRequest;

        emit PurchaseRequested(msg.sender, _seller, _ipfsHash, _price);
    }

    function completePurchase(address _buyer, address _seller, string memory _ipfsHash) public {
        require(msg.sender == _seller, "Only the seller can complete the purchase");

        PurchaseRequest storage request = purchaseRequests[_buyer];
        require(request.isCompleted == false, "Purchase already completed");
        require(request.seller == _seller && keccak256(bytes(request.ipfsHash)) == keccak256(bytes(_ipfsHash)), "Invalid purchase request");

        // Transfer funds to the seller
        payable(_seller).transfer(request.price);

        // Mark the purchase request as completed
        request.isCompleted = true;

        // Mark the data as unavailable
        dataRecords[_seller].isAvailable = false;

        emit PurchaseCompleted(_buyer, _seller, _ipfsHash, request.price);
    }

    function evaluateData(address _dataOwner, uint256 _evaluation) public {
        require(_evaluation >= 0 && _evaluation <= 100, "Evaluation score must be between 0 and 100");
        require(dataRecords[_dataOwner].isAvailable, "Data not available for evaluation");

        dataRecords[_dataOwner].evaluation = _evaluation;

        emit DataEvaluated(msg.sender, _dataOwner, _evaluation);
    }

    function requestArbitration(address _arbitrator, string memory _ipfsHash) public {
        require(dataRecords[msg.sender].isAvailable, "Data not available for arbitration");

        arbitrationRequests[msg.sender][_arbitrator] = true;

        emit ArbitrationRequested(msg.sender, _arbitrator, _ipfsHash);
    }

    function resolveArbitration(address _requester, address _arbitrator, bool _isSimilar) public {
        require(arbitrationRequests[_requester][_arbitrator], "No pending arbitration request");

        if (_isSimilar) {
            // Transfer deposit to the buyer
            payable(_requester).transfer(address(this).balance);

            // Mark the data as unavailable
            dataRecords[_requester].isAvailable = false;

            // Remove seller from allowed sellers
            allowedSellers[_requester] = false;
        }

        emit ArbitrationResolved(_requester, _arbitrator, _isSimilar);
    }
}
