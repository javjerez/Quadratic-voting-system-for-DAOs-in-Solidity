// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

import "hardhat/console.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes,
    uint numTokens) external payable;
}

contract Tokens is ERC20 {
    address private internalOwner;

    //Constructor
    constructor(string memory name_, string memory symbol_, uint nTokens) ERC20 (name_, symbol_) {
        
    }

    // Funcion en tu contrato que llama a _mint
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract ContratoDeLaDuda is IExecutableProposal {
    //Constructor
    constructor(){
    }
    
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external override  payable{

    }
}

contract QuadraticVoting{
    struct tProposal{
        uint id;
        string title;
        string description;
        uint budget;   // signaling: 0, funding: != 0
        address payee;
        uint approved; // 0: Pending, 1: Signaling, 2: Approved, 3: Cancelled, 4: SignalingEjecutada
        address owner;
        uint totalVotes;
        uint totalTokens;
        uint totalVotesAfter;
        uint totalTokensAfter;
        uint indexIterator;
        uint vPeriod;
    }

    struct Participant{
        uint128 remainingEther;
        bool exists;
    }

    Tokens private miToken;

    mapping(uint => mapping(address => uint256)) private nProposalToParticipantToNTokens;
    mapping(uint => mapping(address => uint256)) private nProposalToParticipantVotes;
    mapping(address => Participant) private participantToEther;

    // Provisional
    uint private nProposal = 1;
    uint[] private proposalPending;
    uint[] private proposalCancelled;
    uint[] private proposalSignaling;
    uint[] private proposalApproved;
    mapping(uint => tProposal) private idToProposal;

    // Declaracion atributos
    uint private maxTokens;
    uint private price;
    address private owner;
    bool private votingOpen;
    uint private totalBudget; // Lo inicializamos en el metodo openVoting()
    uint private numParticipants;
    bool private lock = false; // Para evitar ataques de reentrancy
    event Print(string message);
    event TokensPurchased(address buyer, uint256 amount);
    event TokensSold(address buyer, uint256 amount);
    event ProposalApprovedMSG(uint id);
    event ProposalCancelledMSG(uint id);

    uint private votingPeriod;

    //Constructor
    constructor(uint tokenPrice, uint maxToken){
        maxTokens = maxToken;
        owner = msg.sender;
        votingOpen = false;
        price = tokenPrice;
        numParticipants = 0;
        miToken = new Tokens("SufragioCoin", "PS", maxTokens);
        votingPeriod = 0;
    }

    // En vez de respetar los parentesis, respetamos el calculo matematico
    // Para aumentar la precision de la formula, multiplicaremos el 0.2 por un numero grande, y dejaremos la division para el final
    function calcularUmbral(uint budget) private view returns(uint){
        // Hacemos el minimo comun multiplo y obtenes 5 (del 0.2 que es 1/5) multiplicado por el totalBudget
        uint mcm = 5 * totalBudget;

        uint mul = (totalBudget + 5 * budget) * numParticipants;

        uint div = mul / mcm;
        uint threshold1 = div + proposalPending.length;

        console.log("EL THRESHOLD ES: ");
        console.log(threshold1);
        
        return threshold1;
    }

    function evaluarProposal(uint pid) private view returns(bool) {
        uint budget = idToProposal[pid].budget;
        uint totalVotes = idToProposal[pid].totalVotes;

        // Para que una propuesta de funding se apruebe se tienen que dar las siguientes condiciones:
        // 1. Primero comprobamos si el presupuesto total del proceso de votacion es suficiente en el momento de evaluar el umbral
        // 2. El numero de votos recibidos en esa propuesta supera el umbral
        if ((totalBudget >= budget) && (totalVotes > calcularUmbral(budget))) {
            return true;
        }

        return false;
    }

    modifier onlyAuthority(){
        require(msg.sender == owner,"ERROR: No tiene autoridad para hacer eso");
        _;
    }

    modifier participantExists(address p){
        require(participantToEther[p].exists, "ERROR: El participante NO existe");
        _;
    }

    modifier participantNotExists(address p){
        require(!participantToEther[p].exists, "ERROR: El participante YA existe");
        _;
    }

    modifier onlyCreator(address a, address b){
        require(a == b, "ERROR: NO es el creador de la propuesta");
        _;
    }

    modifier enoughCredit(uint value){
        require(value >= price, "ERROR: Cantidad de Ether insuficiente");
        _;
    }

    modifier stillTokensLeft(uint number){
        require(miToken.totalSupply() + number < maxTokens, "ERROR: No quedan tokens a la venta");
        _;
    }

    modifier onlyOpened(){
        require(votingOpen, "ERROR: La votacion NO esta abierta");
        _;
    }

    modifier notApprovedProposal(uint pId){
        require(idToProposal[pId].approved != 2, "ERROR: La propuesta ya ha sido aprobada");
        _;
    }

    modifier signalingProposal(uint pId){
        require(idToProposal[pId].approved == 1, "ERROR: La propuesta no es de signaling");
        _;
    }
    modifier samePeriod(uint period){
        require(votingPeriod == period, "ERROR: La propuesta no esta en el mismo periodo de votacion");
        _;
    }    
    modifier notSamePeriod(uint period){
        require(votingPeriod != period || (votingPeriod == period && !votingOpen), "ERROR: La propuesta esta en el mismo periodo de votacion");
        _;
    }

    // Funciones
    function openVoting() public onlyAuthority payable{
        require(!votingOpen, "ERROR: La propuesta ya se ha abierto");
        //Utilizamos el Modifier only Authority para asegurarnos que solo lo puede ejcutar el propietario del contrato
        totalBudget = msg.value;

        // Actualizamos el periodo de votacion en el que nos encontramos
        votingPeriod++;

        // Abrimos la votacion
        votingOpen = true;
    }

    // La funcion es 'payable' para poder acceder al msg.value
    function addParticipant() public enoughCredit(msg.value) participantNotExists(msg.sender) payable{
        // Miramos cuantos tokens puede crear con el importe introducido
        uint number = msg.value / price;
        uint remaining = msg.value % price;
        require(miToken.totalSupply() + number <= maxTokens, "ERROR: No quedan tokens a la venta");

        // Guardamos el ether sobrante del participante
        if(!participantToEther[msg.sender].exists){
            Participant memory p = Participant(uint128(remaining), true);
            participantToEther[msg.sender] = p;
        }else{
            participantToEther[msg.sender].remainingEther += uint128(remaining);
            participantToEther[msg.sender].exists = true;
        }

        // Aumentamos el numero de participantes
        unchecked {
            numParticipants++;//Es imposible que tengamos mas de 2^256 participantes
        }

        // Inluimos los tokens nuevos del participante al ERC20
        miToken.mint(msg.sender, number);
        emit Print("Se ha registrado un participante");
        emit TokensPurchased(msg.sender, number);
    }
    
    function removeParticipant() public participantExists(msg.sender) payable{
        // Decrementamos el numero de participantes
        numParticipants--;
        participantToEther[msg.sender].exists = false;
        emit Print("Se ha eliminado un participante");  
        
    }

    function addProposal(string memory title_, string memory description_, uint budget_, address payee_) public
             onlyOpened participantExists(msg.sender) returns (uint){
        
        tProposal memory newProposal = tProposal({
            id: nProposal,
            title: title_,
            description: description_,
            budget: budget_,
            payee: payee_, // Dirección del destinatario
            approved: 0,
            owner: msg.sender, // Dirección del creador de la propuesta
            totalVotes: 0,
            totalTokens: 0,
            totalVotesAfter: 0,
            totalTokensAfter: 0,
            indexIterator: 0,
            vPeriod: votingPeriod
        });

        // Comprobamos el numero del budget para meter la propuesta en el array correspondiente
        if (budget_ == 0){
            newProposal.approved = 1;
            idToProposal[newProposal.id].indexIterator = proposalSignaling.length;
            proposalSignaling.push(newProposal.id);
        }
        else {
            idToProposal[newProposal.id].indexIterator = proposalPending.length;
            proposalPending.push(newProposal.id);
        }
        // En ambas listas, guardamos el iterador de la propuesta en esa lista para acceder a ella en tiempo constante
        
        // Mappeamos la nueva propuesta
        idToProposal[newProposal.id] = newProposal;

        unchecked{
            nProposal++;
        }
        
        emit Print("Se ha creado una nueva propuesta");
        return newProposal.id;
    }

    function cancelProposal(uint id) public onlyOpened samePeriod(idToProposal[id].vPeriod) onlyCreator(msg.sender, idToProposal[id].owner) {
        // Obtenemos el estado de la propuesta
        uint typeProposal = idToProposal[id].approved;

        // Si no ha sido todavia aprobada
        if(typeProposal != 2){
            // Obtenemos el iterador de la propuesta
            uint indexToCancel = idToProposal[id].indexIterator;

            if(typeProposal == 0){
                // Obtenemos la posicion de la ultima propuesta de pending
                uint lastIndex = proposalPending.length - 1;

                // Obtenemos el ID de la ultima propuesta de pending
                uint lastProposalId = proposalPending[lastIndex];

                // Intercambiamos las posiciones de la proposal que queremos eliminar con la ultima proposal de la lista
                proposalPending[indexToCancel] = lastProposalId;
                idToProposal[lastProposalId].indexIterator = indexToCancel;

                // Eliminamos la ultima propuesta de la lista, es decir, la propuesta que queriamos eliminar
                proposalPending.pop();
            }
            else if(typeProposal == 1){
                // Obtenemos la posicion de la ultima propuesta de signaling
                uint lastIndex = proposalSignaling.length - 1;

                // Obtenemos el ID de la ultima propuesta de signaling
                uint lastProposalId = proposalSignaling[lastIndex];

                // Intercambiamos las posiciones de la proposal que queremos eliminar con la ultima proposal de la lista
                proposalSignaling[indexToCancel] = lastProposalId;
                idToProposal[lastProposalId].indexIterator = indexToCancel;

                // Eliminamos la ultima propuesta de la lista, es decir, la propuesta que queriamos eliminar
                proposalSignaling.pop();
            }

            // Marcamos la propuesta como cancelada
            idToProposal[id].approved = 3;

            // Incluimos la propuesta en la lista de propuestas canceladas
            proposalCancelled.push(id);
            emit Print("Se ha cancelado una propuesta");
            emit ProposalCancelledMSG(id);
        }
    }
    
    function buyTokens() public participantExists(msg.sender) enoughCredit(msg.value) payable{
        // El participante compra tokens con el ether sobrante que tenia y la cantidad introducida
        uint aux = uint(participantToEther[msg.sender].remainingEther);
        uint number = (msg.value + aux) / price;

        require(miToken.totalSupply() + number <= maxTokens, "ERROR: No quedan tokens a la venta");
        // Calculamos el ether sobrante de la compra
        uint remaining = (msg.value + aux) % price;
        
        // Incluimos los tokens nuevos del participante al ERC20
        miToken.mint(msg.sender, number);

        // Actualizamos el ether sobrante del participante
        participantToEther[msg.sender].remainingEther = uint128(remaining);
        emit Print("Se han comprado Tokens");
        emit TokensPurchased(msg.sender, number);
    }
    
    function sellTokens(uint sell) public participantExists(msg.sender) payable{
        require(sell <= miToken.balanceOf(msg.sender),"ERROR: No tienes los tokens introducidos");
        
        // Vendemos los tokens seleccionados y devolvemos tambien el Ether acumulado del participante
        uint aux = uint(participantToEther[msg.sender].remainingEther);
        uint money = sell * price + aux;
        payable(msg.sender).transfer(money);

        // El ether acumulado del participante ahora es cero
        participantToEther[msg.sender].remainingEther = uint128(0);

        // Destruimos los tokens seleccionados del participante
        miToken.burn(msg.sender, sell);
        emit Print("Se han vendido Tokens");
        emit TokensSold(msg.sender, sell);
    }
    
    function getERC20() public view returns(address){
        return address(miToken);
    }
    
    function getPendingProposals() public view onlyOpened returns(uint[] memory){
        return proposalPending;
    }
    
    function getApprovedProposals() public view onlyOpened returns(uint[] memory){
        return proposalApproved;
    }
    
    function getSignalingProposals() public view onlyOpened returns(uint[] memory){
        return proposalSignaling;
    }
    
    function getProposalInfo(uint id) public view onlyOpened returns(tProposal memory){
        return idToProposal[id]; 
    }
    
    // Funcion auxiliar para elevar al cuadrado
    function powerOf2(uint x) private pure returns(uint){
        return x*x;
    }

    function stake(uint votes, uint id) public onlyOpened participantExists(msg.sender) samePeriod(idToProposal[id].vPeriod) {
        require(!lock, "Contract locked"); // Miramos si la funcion la ha cogido alguien mas
        
        console.log("ESTAMOS DENTRO DEL STAKE");

        // Tenemos un mapa con la propuesta como clave, que guarda el numero de votos que lleva cada participante
        uint nVotes = nProposalToParticipantVotes[id][msg.sender];
        
        // Calculamos los tokens necesarios para depositar los votos nuevos
        uint tokenNeeded =  powerOf2(nVotes + votes) - powerOf2(nVotes);

        console.log(tokenNeeded);

        // Hacemos la transferencia de tokens:
        
        // Le restamos los el numero de tokens al usuario que acaba de votar
        miToken.transferFrom(msg.sender, address(this), tokenNeeded);
        
        // Actualizamos la propuesta con los nuevos tokens
        nProposalToParticipantToNTokens[id][msg.sender] += tokenNeeded;
        idToProposal[id].totalTokens += tokenNeeded;

        // Actualizamos los votos totales del particpiante
        nProposalToParticipantVotes[id][msg.sender] += votes;
        idToProposal[id].totalVotes += votes;


        idToProposal[id].totalTokensAfter += tokenNeeded;
        idToProposal[id].totalVotesAfter += votes;

        // Comprobamos si con los nuevos votos se dan las condiciones para aprobar la propuesta, para ello llamamos al _checkAndExecuteProposal()
        // Comprobamos que la propuesta sea de tipo funding
        if (idToProposal[id].budget != 0) {
            
            console.log("DENTRO DEL IF DEL CHECK");

            _checkAndExecuteProposal(id); 
        }
    }
    
    function withdrawFromProposal(uint votes, uint id) public notApprovedProposal(id) participantExists(msg.sender){
        require(!lock, "Contract locked"); // Miramos si la funcion la ha cogido alguien mas
        
        // Comprobamos que la propuesta no ha sido cancelada ni aprobada a través de modifiers

        // Comprobamos que el numero de votos que puedo retirar es valido
        uint nVotes = nProposalToParticipantVotes[id][msg.sender];

        // Protegemos el contrato de un ataque de 'underflow'
        require(votes <= nVotes, "ERROR: no puedes retirar esos votos");

        // Calculo cuantos tokens tengo que devolerle al participante
       uint tokenReturned;
      
        unchecked {//Sabemos que el participante tiene esos tokens porque hemos comprobado que tiene esos votos
           tokenReturned =  powerOf2(nVotes) -  powerOf2(nVotes - votes);
        }
        miToken.transfer(msg.sender, tokenReturned);
        // Actualizamos los mapas para registrar el intercambio de tokens y el numero de votos
        nProposalToParticipantVotes[id][msg.sender] -= votes;
        nProposalToParticipantToNTokens[id][msg.sender] -=  tokenReturned;
        idToProposal[id].totalTokens -= tokenReturned;
        idToProposal[id].totalVotes -= votes;

        if(idToProposal[id].vPeriod == votingPeriod && votingOpen){
            idToProposal[id].totalTokensAfter -= tokenReturned;
            idToProposal[id].totalVotesAfter -= votes;
        }

        emit Print("Se han devuelto Tokens");
        emit TokensSold(msg.sender, tokenReturned);
    }

    function executeSignaling(uint id) public notSamePeriod(idToProposal[id].vPeriod) signalingProposal(id) onlyCreator(msg.sender, idToProposal[id].owner){
        require(!lock, "Contract locked"); // Miramos si la funcion la ha cogido alguien mas
       
        uint nProposalVotes = idToProposal[id].totalVotesAfter;
        uint nProposalTokens = idToProposal[id].totalTokensAfter;

        console.log("NUMERO DE VOTOS DE LA PROPUESTA: ");
        console.log(nProposalVotes);
        console.log("NUMERO DE TOKENS DE LA PROPUESTA: ");
        console.log(nProposalTokens);

        // 1. Ejecutamos el 'executeProposal' del contrato externo, hay que limitar la cantidad de gas de la llamada (max 100.000 gas)
        // 2. Transferimos el dinero presupuestado a 'executeProposal'
        lock = true;
        (bool sent, ) = (idToProposal[id].payee).call{value: idToProposal[id].budget, gas: 100000}(
        abi.encodeWithSignature("executeProposal(uint256,uint256,uint256)", id, nProposalVotes, nProposalTokens));
        lock = false;
        require(sent, "Failed to send funds");

        idToProposal[id].approved = 4;
    }

    // Checkear vulnerabilidad
    function _checkAndExecuteProposal(uint id) internal {  
        // La proposal NO debe ser 'signaling', lo comprobamos en el 'if' de la funcion 'stake'
        require(!lock, "Contract locked"); // Miramos si la funcion la ha cogido alguien mas
        // Comprueba condiciones para ejecutar una propuesta de tipo funding

        console.log("ESTAMOS DENTRO DEL CHECK");

        if (evaluarProposal(id)){

            console.log("ESTAMOS DENTRO DEL IF DEL CHECK");

            // Si se dan las condiciones se aprueba la propuesta:

            // Primero actualizamos el presupuesto disponible de la propuesta (sumamos el importe de tokens y votos al budget)
            uint nProposalVotes = idToProposal[id].totalVotes;
            uint nProposalTokens = idToProposal[id].totalTokens;

            console.log("NUMERO DE VOTOS DE LA PROPUESTA: ");
            console.log(nProposalVotes);
            console.log("NUMERO DE TOKENS DE LA PROPUESTA: ");
            console.log(nProposalTokens);

            // 1. Ejecutamos el 'executeProposal' del contrato externo, hay que limitar la cantidad de gas de la llamada (max 100.000 gas)
            // 2. Transferimos el dinero presupuestado a 'executeProposal'
            lock = true;
            (bool sent, ) = (idToProposal[id].payee).call{value: idToProposal[id].budget, gas: 100000}(
            abi.encodeWithSignature("executeProposal(uint256,uint256,uint256)", id, nProposalVotes, nProposalTokens));
            lock = false;
            require(sent, "Failed to send funds");

            console.log("HEMOS HECHO LA LLAMADA EXTERNA");

            // Actualizamos el budget total del contrato disponible para propuestas
            totalBudget = totalBudget + (nProposalTokens * price) - idToProposal[id].budget;

            console.log("EL TOTAL BUDGET ES: ");
            console.log(totalBudget);

            // Aplicamos el 'iterator trick' para eliminar una propuesta de la lista de Pending en tiempo constante
            uint indexToCancel = idToProposal[id].indexIterator;
            uint lastIndex = proposalPending.length - 1;

            // Obtenemos el ID de la ultima propuesta de pending
            uint lastProposalId = proposalPending[lastIndex];

            // Intercambiamos las posiciones de la proposal que queremos eliminar con la ultima proposal de la lista
            proposalPending[indexToCancel] = lastProposalId;
            idToProposal[lastProposalId].indexIterator = indexToCancel;

            // Eliminamos la ultima propuesta de la lista, es decir, la propuesta que queriamos eliminar
            proposalPending.pop();

            //Incluimos la propuesto en la lista de aprobadas
            idToProposal[id].indexIterator = proposalApproved.length;
            proposalApproved.push(id);
            idToProposal[id].approved = 2;

            miToken.burn(address(this), nProposalVotes);
            emit Print("Se ha aprobado la propuesta");
            emit ProposalApprovedMSG(id);
        }
        // else
        // La propuesta no se aprueba
    }
    
    function closeVoting() public payable onlyAuthority onlyOpened {
        // Comprobamos que la accede el creador del contrato y la votación está abierta

        // Cerramos el proceso de votacion
        votingOpen = false;

        // 5. El presupuesto sobrante se transfiere al owner del contrato
        payable(msg.sender).transfer(totalBudget);
        
    }
}