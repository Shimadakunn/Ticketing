// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TicketingSystem{

    uint256 public artistCounter = 1;
    struct Artist {
        bytes32 name;
        uint256 artistCategory;
        address owner;
        uint256 totalTicketSold;
    }
    mapping(uint256 => Artist) public artistsRegister;
    function createArtist(bytes32 _name, uint256 _artistCategory) public {
        Artist memory newArtist = Artist(_name, _artistCategory, msg.sender, 0);
        artistsRegister[artistCounter] = newArtist;
        artistCounter++;
    }
    function modifyArtist(uint _artistId, bytes32 _name, uint _artistCategory, address _newOwner) public {
        Artist storage artist = artistsRegister[_artistId];
        require(msg.sender == artist.owner, "not the owner");
        artist.name = _name;
        artist.artistCategory = _artistCategory;
        artist.owner = _newOwner;
    }

    uint256 public venueCounter = 1;
    struct Venue {
        bytes32 name;
        uint256 capacity;
        uint256 standardComission;
        address payable owner;
    }
    mapping(uint256 => Venue) public venuesRegister;
    function createVenue(bytes32 _name, uint256 _capacity, uint256 _standardComission) public {
        Venue memory newVenue = Venue(_name, _capacity, _standardComission, payable(msg.sender));
        venuesRegister[venueCounter] = newVenue;
        venueCounter++;
    }
    function modifyVenue(uint256 _venueId, bytes32 _name, uint256 _capacity, uint256 _standardComission, address payable _to) public{
        Venue storage venue = venuesRegister[_venueId];
        require(msg.sender == venue.owner, "not the venue owner");
        venue.name = _name;
        venue.capacity = _capacity;
        venue.standardComission = _standardComission;
        venue.owner = _to;
    }

    uint256 public concertCounter = 1;
    struct Concert {
        uint256 artistId;
        uint256 venueId;
        uint256 concertDate;
        uint256 ticketPrice;
        bool validatedByArtist;
        bool validatedByVenue;
        uint256 totalSoldTicket;
        uint256 totalMoneyCollected;
    }
    mapping(uint256 => Concert) public concertsRegister;
    function createConcert(uint256 _artistId, uint256 _venueId, uint256 _concertDate, uint256 ticketPrice) public {
        bool _validatedByArtist = false;
        if(msg.sender == artistsRegister[1].owner){
            _validatedByArtist = true;
        }
        Concert memory newconcert = Concert(_artistId,_venueId,_concertDate,ticketPrice,_validatedByArtist,false,0,0);
        concertsRegister[concertCounter] = newconcert;
        concertCounter++;
    }
    function validateConcert(uint256 _concertId) public {
        Concert storage concert = concertsRegister[_concertId];
        concert.validatedByArtist = true;
        concert.validatedByVenue = true;
    }

    uint256 public ticketCount = 1;
    struct Ticket {
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }
    mapping(uint256 => Ticket) public ticketsRegister;
    function emitTicket(uint _concertId, address payable _ticketOwner) public {
        Concert storage concert = concertsRegister[_concertId];
        require(msg.sender == artistsRegister[1].owner,"not the owner");
        Ticket memory newticket = Ticket(_concertId,_ticketOwner,true,false,0);
        ticketsRegister[ticketCount] = newticket;
        ticketCount++;
        concert.totalSoldTicket++;
    }
    function useTicket(uint _ticketId) public {
        Ticket storage ticket = ticketsRegister[_ticketId];
        require(msg.sender == ticket.owner, "sender should be the owner");
        require(
            block.timestamp <= concertsRegister[ticket.concertId].concertDate
            && block.timestamp >= concertsRegister[ticket.concertId].concertDate - 60 * 60 * 24,"should be used the d-day");
        require(concertsRegister[ticket.concertId].validatedByVenue == true,"should be validated by the venue");
        ticket.isAvailable = false;
        ticket.isAvailableForSale = false;
        ticket.owner = payable(address(0));
        ticket.amountPaid = concertsRegister[ticket.concertId].ticketPrice;
        concertsRegister[ticket.concertId].totalMoneyCollected += ticket.amountPaid;
    }

    function buyTicket(uint _concertId) payable public {
        Ticket memory newticket = Ticket(_concertId,payable(msg.sender),true,false,msg.value);
        ticketsRegister[ticketCount] = newticket;
        Concert storage concert = concertsRegister[_concertId];
        ticketCount++;
        concert.totalSoldTicket++;
        concert.totalMoneyCollected += concert.ticketPrice;
    }
    function transferTicket(uint _ticketId, address payable _to) public {
        Ticket storage ticket = ticketsRegister[_ticketId];
        require(msg.sender == ticket.owner, "not the ticket owner");
        ticket.owner = _to;
    }
    function cashOutConcert(uint _concertId, address payable _cashOutAddress) public {
        require(msg.sender ==artistsRegister[concertsRegister[_concertId].artistId].owner,"should be the artist");
        require(concertsRegister[_concertId].concertDate <= block.timestamp,"should be after the concert");
        uint256 totalTicketSale = concertsRegister[_concertId].totalSoldTicket *concertsRegister[_concertId].ticketPrice;
        uint256 venueShare = (totalTicketSale *venuesRegister[concertsRegister[_concertId].venueId].standardComission) /10000;
        uint256 artistShare = totalTicketSale - venueShare;
        (bool success, ) = _cashOutAddress.call{value: artistShare}("");
        (bool success2, ) = payable(venuesRegister[1].owner).call{value: venueShare}("");
        artistsRegister[1].totalTicketSold += concertsRegister[_concertId].totalSoldTicket;
        require(success && success2, "Transfer failed.");
    }
    function offerTicketForSale(uint256 _ticketId, uint256 _salePrice) public {
        require(msg.sender == ticketsRegister[_ticketId].owner,"should be the owner");
        require(_salePrice < ticketsRegister[_ticketId].amountPaid,"should be less than the amount paid");
        ticketsRegister[_ticketId].isAvailableForSale = true;
        ticketsRegister[_ticketId].amountPaid = _salePrice;
    }

    function buySecondHandTicket(uint256 _ticketId) public payable {
        require( msg.value > concertsRegister[ticketsRegister[_ticketId].concertId].ticketPrice - 3,"not enough funds");
        require(ticketsRegister[_ticketId].isAvailableForSale,"should be available");
        ticketsRegister[_ticketId].owner = payable(msg.sender);
        ticketsRegister[_ticketId].isAvailableForSale = false;
        ticketsRegister[_ticketId].amountPaid = msg.value;
    }
}