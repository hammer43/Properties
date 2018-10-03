pragma solidity ^0.4.25;
//import "http://github.com/oraclize/ethereum-api/oraclizeAPI_0.4.sol";
contract PropertyManager  {
    
    event  RENT_SUCCESSFUL(address addressToSend,string message);
    event CONTRACT_TERMINATED(address addressToSend,uint propId,string message);
    event TENANT_DEFAULT(address brokerAddress,uint propId,address renterAddress,string message);
    
    struct Property { 
    
        uint PropertyID; 
        uint RentAmount;
        uint RentalPeriod; // In seconds to test
        bool Rented; 
        
    }
   struct Owner { 
      address OwnerID; 
   }
    
   struct Renter { 
      address RenterID; 
      uint RentBalance;
   }
   struct Broker { 
     address BrokerID;   
     
   }
   
   Broker[] Brokers;
   
   
   /* mapping from  Property to Owner */ 
   mapping( uint => Owner) public Owners; 
   
    /* mapping from  Property to Renters*/ 
   mapping( uint => Renter)  public Renters; 
  
   /* mapping to ID from Property used in setting rented flags */ 
   mapping(uint => Property) public Properties;  
   
   //Stores proeprty id and query id mapping for call backs
   mapping (bytes32 => uint) public pendingQueries;
   
   modifier ownerCheck(uint _propID){
        require(Owners[_propID].OwnerID == msg.sender,"Only owners can list the property");
        _;
   }
  modifier rentCheck(uint _propID){
        require(Properties[_propID].PropertyID ==0,"No such property exist");
        require(Renters[_propID].RenterID == 0,"Cannot load rent without Renting");   
        require(msg.value >= Properties[_propID].RentAmount,"Cannot load rent, Insufficient rent loaded");
        _;
  }
   
   modifier isRentable(uint _propID){
       require(!Properties[_propID].Rented,"Already Rented");
       require(msg.value >= Properties[_propID].RentAmount,"Insufficient Rent for the property");
       require(Owners[_propID].OwnerID!=msg.sender,"Owner cannot rent thier own property");
       _;
   }
   function listProperty(uint _propID,uint _rent,uint _rentalPeriod) public  ownerCheck(_propID) {
      
       Property storage property;
       property.PropertyID = _propID;
       property.RentAmount = _rent;
       property.RentalPeriod = _rentalPeriod;
       Properties[_propID] = property;
   }
   
   function loadRent(uint _propID) public payable rentCheck(_propID){
        
        Renters[_propID].RentBalance += msg.value;
   }
   
  
    function setOwner( uint  _propID)  public {
         Owner storage  tmpOwner; 
         tmpOwner.OwnerID = msg.sender;
         Owners[_propID]  = tmpOwner;
    }
   
    function setRenter( uint  _propID)  public payable isRentable(_propID){
         Renter storage tmpRenter; 
         tmpRenter.RenterID = msg.sender;
         Renters[_propID]  = tmpRenter;
         Properties[_propID].Rented = true; 
         Owners[_propID].OwnerID.transfer( Properties[_propID].RentAmount);
         emit RENT_SUCCESSFUL(Renters[_propID].RenterID,"Rented successfully");
         
         //Schedule payments in Property.RentalPeriod interval to be retrieved from contract
         
          // bytes32 queryId = oraclize_query(Properties[_propID].RentalPeriod, "URL", "");
          // pendingQueries[queryId] = _propID;
        
    }
 
   function setBroker() public{ 
      Broker storage tmpBroker; 
      tmpBroker.BrokerID= msg.sender;
      Brokers.push(tmpBroker);
   }
   
   function __callback(bytes32 myid, string result) {
       // if (msg.sender != oraclize_cbAddress()) throw;
        
        //Check if the RentBalance covers the periodic rent
         uint propID = pendingQueries[myid];
        if(Renters[propID].RentBalance < Properties[propID].RentAmount){
            //Terminate Contract with the renter and send the message Contract is terminated and vacate the Property
            
            //Return the balance back to renter if any 
            Renters[propID].RenterID.transfer(Renters[propID].RentBalance);
            emit CONTRACT_TERMINATED(Renters[propID].RenterID,propID,"Your rental contact is Terminated");
            
            //Make the propery avialble
            Properties[propID].Rented = false;
            emit CONTRACT_TERMINATED(Owners[propID].OwnerID,propID,"Your rental contact is Terminated because tenant defaulted");
            
            //Notify incident subscriber about the default from the tenant 
            uint brokerCount = Brokers.length;
            
            for(uint i=0;i<brokerCount;i++){
               emit TENANT_DEFAULT(Brokers[i].BrokerID,propID,Renters[propID].RenterID,"Notification: Tentant defaulted ");
            }
            
            //Tenant to vacate the Property
            delete Renters[propID];
        
            
        }
        // Deduct rent after interval
        
      
        Owners[propID].OwnerID.transfer(Properties[propID].RentAmount);
        
        
        
    }
   
}