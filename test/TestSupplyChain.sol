pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract TestSupplyChain {

    // Test for failing conditions in this contracts:
    // https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests

    uint public initialBalance = 50 ether;

    SupplyChain supplyChain;
    TheSeller theSeller;

    // beforeEach works before running each test
    function beforeEach() public {
        supplyChain = new SupplyChain();
        (bool r, ) = address(supplyChain).call.value(1 ether)("");

        theSeller = new TheSeller(supplyChain);
        (r, ) = address(theSeller).call.value(1 ether)("");
        theSeller.addItem("Item 1", 0.2 ether);
    }

    // buyItem

    // test for failure if user does not send enough funds
    function testBuyerDoesNotSendEnoughFunds() public {

        bytes memory payload = abi.encodeWithSignature("buyItem(uint256)", 0);

        ( , , uint256 itemPrice, , , ) = supplyChain.fetchItem(0);
        Assert.isTrue(itemPrice > 0.1 ether, "Try buying with not enough funds.");

        (bool r, ) = address(supplyChain).call.value(0.1 ether)(payload);
        Assert.isFalse(r, "There must be error when buying with not enough funds.");

        Assert.isTrue(itemPrice < 0.5 ether, "Try buying with enough funds.");
        (r, ) = address(supplyChain).call.value(0.5 ether)(payload);
        Assert.isTrue(r, "There must be able to buy item with enough funds.");
    }

    // test for purchasing an item that is not for Sale
    function testBuyerPurchasesNotForSaleItem() public {

        ( , , , uint256 itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(0, itemState, "The item is in For Sale state");
        bytes memory payload = abi.encodeWithSignature("buyItem(uint256)", 0);
        (bool r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isTrue(r, "Error buying the item.");

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(1, itemState, "The item is in Sold state");
        (r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isFalse(r, "Must not be able to buy the item in Sold state.");

    }

    // shipItem

    // test for calls that are made by not the seller
    function testNotSellerShipsItem() public {

        bytes memory payload = abi.encodeWithSignature("buyItem(uint256)", 0);
        (bool r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isTrue(r, "Error buying the item.");

        payload = abi.encodeWithSignature("shipItem(uint256)", 0);
        (r, ) = address(supplyChain).call(payload);
        Assert.isFalse(r, "Must be seller to ship the item.");

        ( , , , uint256 itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(1, itemState, "The item must be still in sold state");

        theSeller.shipItem(0);
        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(2, itemState, "The item must be in shipped state");
    }

    // test for trying to ship an item that is not marked Sold
    function testSellerShipItemThatNotSold() public {

        bytes memory payload = abi.encodeWithSignature("shipItem(uint256)", 0);
        (bool r, ) = theSeller.shipItem(0);
        Assert.isFalse(r, "Must not be able to ship not sold item.");

        payload = abi.encodeWithSignature("buyItem(uint256)", 0);
        (r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isTrue(r, "Error buying the item.");

        ( , , , uint256 itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(1, itemState, "The item must be in Sold state");
        
        payload = abi.encodeWithSignature("shipItem(uint256)", 0);
        (r, ) = theSeller.shipItem(0);
        Assert.isTrue(r, "Must be able to ship Sold item.");

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(2, itemState, "The item must be in Shipped state");

    }


    // receiveItem

    // test calling the function from an address that is not the buyer
    function testNotBuyerReceivesItem() public {

        bytes memory payload = abi.encodeWithSignature("buyItem(uint256)", 0);
        (bool r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isTrue(r, "Error buying the item.");

        ( , , , uint256 itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(1, itemState, "The item must be in Sold state");
        
        payload = abi.encodeWithSignature("shipItem(uint256)", 0);
        (r, ) = theSeller.shipItem(0);

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(2, itemState, "The item must be in Shipped state");

        (r, ) = theSeller.receiveItem(0);
        Assert.isFalse(r, "Must be buyer to receive item.");

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(2, itemState, "The item must still be in Shipped state");

        payload = abi.encodeWithSignature("receiveItem(uint256)", 0);
        (r, ) = address(supplyChain).call(payload);
        Assert.isTrue(r, "Buyer nust be able to receive item.");

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(3, itemState, "The item must be in Received state");

    }

    // test calling the function on an item not marked Shipped
    function testBuyerReceivesItemThatNotShipped() public {

        
        bytes memory payload = abi.encodeWithSignature("buyItem(uint256)", 0);
        (bool r, ) = address(supplyChain).call.value(0.2 ether)(payload);
        Assert.isTrue(r, "Error buying the item.");

        ( , , , uint256 itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(1, itemState, "The item must be in Sold state");

        payload = abi.encodeWithSignature("receiveItem(uint256)", 0);
        (r, ) = address(supplyChain).call(payload);
        Assert.isFalse(r, "Buyer must not be able to receive item in Sold state.");
        
        payload = abi.encodeWithSignature("shipItem(uint256)", 0);
        (r, ) = theSeller.shipItem(0);

        payload = abi.encodeWithSignature("receiveItem(uint256)", 0);
        (r, ) = address(supplyChain).call(payload);
        Assert.isTrue(r, "Buyer must be able to receive item.");

        ( , , , itemState, , ) = supplyChain.fetchItem(0);
        Assert.equal(3, itemState, "The item must be in received state");

    }

    function () external payable {}

}

// Proxy contract for testing throws
contract TheSeller {
    SupplyChain private target;

    constructor(SupplyChain _target) public {
        target = _target;
    }

    function addItem(string memory _name, uint256 _price) public returns (bool) {
        return target.addItem(_name, _price);
    }

    function shipItem(uint256 _sku) public returns (bool, bytes memory) {

        bytes memory payload = abi.encodeWithSignature("shipItem(uint256)", _sku);
        return address(target).call(payload);
        
    }

    function receiveItem(uint256 _sku) public returns (bool, bytes memory) {

        bytes memory payload = abi.encodeWithSignature("receiveItem(uint256)", _sku);
        return address(target).call(payload);
        
    }

    function () external payable {}
}
