// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/payment/escrow/RefundEscrow.sol";

contract ProductNFT is ERC721, ReentrancyGuard, Ownable {
    constructor() ERC721("GI-Connect", "GIC") {}

    struct Product {
        string name;
        uint256 giTag;  // GI tag variable
        // Add any other relevant information about the product
    }

    struct Batch {
        string name;
        uint256 quantity;
        uint256 startTokenId;
        uint256 endTokenId;
        bool verification;
        address owner;
        uint256 currentPrice;
        mapping(uint256 => Product) products; // List of products within the batch
    }

    mapping(uint256 => Batch) batchData;
    mapping(uint256 => RefundEscrow) private escrows;

    mapping(uint256 => bool) hasBuyerApproved;
    mapping(uint256 => bool) hasLogisticsApproved;

    event ProductUpdated(uint256 batchId, uint256 tokenId, string updatedInfo);
    event EscrowDeposit(uint256 batchId, address indexed sender, uint256 amount);
    event EscrowClosed(uint256 batchId, address indexed beneficiary, uint256 amount);
    event TransferWithEscrow(uint256 batchId, address indexed sender, address indexed recipient);

    function batchMint(
        uint256 quantity,
        string memory name,
        uint256 batchUid,
        uint256[] memory giTags
    ) public onlyOwner {
        uint256 start = _nextTokenId();
        batchData[batchUid].name = name;
        batchData[batchUid].quantity = quantity;
        batchData[batchUid].startTokenId = start;
        batchData[batchUid].endTokenId = start + quantity;
        batchData[batchUid].verification = false;
        batchData[batchUid].owner = msg.sender;
        batchData[batchUid].currentPrice = 0;

        require(giTags.length == quantity, "Invalid number of GI tags");

        for (uint256 i = 0; i < quantity; i++) {
            batchData[batchUid].products[start + i] = Product({
                name: name,
                giTag: giTags[i]
                // Add any other relevant information about the product
            });

            _mint(msg.sender, start + i);
        }
    }

    function updateProductInfo(
        uint256 batchId,
        uint256 tokenId,
        string memory updatedInfo
    ) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved or not owner");
        batchData[batchId].products[tokenId].name = updatedInfo;
        emit ProductUpdated(batchId, tokenId, updatedInfo);
    }

    function getProductInfo(uint256 batchId, uint256 tokenId) public view returns (Product memory) {
        require(tokenId >= batchData[batchId].startTokenId && tokenId < batchData[batchId].endTokenId, "Token ID not part of batch");
        return batchData[batchId].products[tokenId];
    }

    function getBatchData(uint256 batchId) public view returns (Batch memory) {
        return batchData[batchId];
    }

    function regulatorApproval(uint256 batchId) public onlyOwner {
        batchData[batchId].verification = true;
    }

    function purchaseProduct(uint256 batchId, uint256 price) public payable {
        require(batchData[batchId].verification, "Batch not verified yet");
        require(msg.value == price, "Incorrect price sent");
        require(!hasBuyerApproved[batchId] && !hasLogisticsApproved[batchId], "Escrow has ended");

        if (escrows[batchId] == RefundEscrow(address(0))) {
            escrows[batchId] = new RefundEscrow(batchData[batchId].owner);
        }

        escrows[batchId].deposit{value: msg.value}(msg.sender);
        emit EscrowDeposit(batchId, msg.sender, msg.value);
    }

    function escrowEndBuyer(uint256 batchId) public nonReentrant {
        require(batchData[batchId].verification, "Batch not verified yet");
        require(!hasBuyerApproved[batchId], "Buyer has already approved");
        require(escrows[batchId].address() != address(0), "Escrow not initialized");

        hasBuyerApproved[batchId] = true;

        if (hasLogisticsApproved[batchId]) {
            closeEscrow(batchId);
        }
    }

    function escrowEndLogistics(uint256 batchId) public nonReentrant {
        require(batchData[batchId].verification, "Batch not verified yet");
        require(!hasLogisticsApproved[batchId], "Logistics has already approved");
        require(escrows[batchId].address() != address(0), "Escrow not initialized");

        hasLogisticsApproved[batchId] = true;

        if (hasBuyerApproved[batchId]) {
            closeEscrow(batchId);
        }
    }

    function closeEscrow(uint256 batchId) internal {
        RefundEscrow escrow = escrows[batchId];
        escrow.close();
        escrow.beneficiaryWithdraw();

        Batch storage data = batchData[batchId];
        address newOwner = msg.sender; // Assuming the caller is the new owner

        for (uint256 i = data.startTokenId; i < data.endTokenId; i++) {
            safeTransferFrom(data.owner, newOwner, i);
            emit TransferWithEscrow(batchId, data.owner, newOwner);
        }

        data.owner = newOwner;
        emit EscrowClosed(batchId, data.owner, data.currentPrice);
    }
}